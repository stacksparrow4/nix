"""Command bridge server.

Serves the protocol spoken by ``common/home/ai/pi/extensions/pi-remote.ts``, so
that a caller outside the sandbox can run commands inside it.

Wire format, newline-delimited JSON over a unix socket, one command per
connection:

    -> {"command": "...", "timeout": <seconds>|null}
    <- {"type": "stdout"|"stderr", "data": "<base64>"}   (streamed, repeated)
    <- {"type": "exit", "code": <int>}
      | {"type": "error", "message": "..."}

Details the client depends on, do not change casually:

* Output must be streamed as it arrives; the client renders it live.
* The connection must be closed after the final message; the client only
  settles its promise on socket close.
* A timeout must be reported as an ``error`` whose message *starts with*
  "timeout" -- the client detects timeouts with /^timeout/i rather than by
  looking at a field.
* The client cancels by half-closing its end of the socket, and expects that to
  kill the running command.
* A null timeout means "use the server default".
"""

import base64
import json
import os
import shlex
import signal
import socket
import subprocess
import threading
from pathlib import Path

# Used when the client sends `"timeout": null`.
DEFAULT_COMMAND_TIMEOUT = 60

# Longest path a unix socket can be bound to, minus the NUL terminator.
MAX_SOCKET_PATH = 107

_READ_SIZE = 65536


def validate_socket_path(path):
    """Check a caller-supplied socket path, returning it as a Path."""
    p = Path(path)

    if not p.is_absolute():
        return None, f"must be an absolute path, got {path!r}"
    if len(str(p).encode()) > MAX_SOCKET_PATH:
        return None, f"is longer than {MAX_SOCKET_PATH} bytes: {p}"
    if not p.parent.is_dir():
        return None, f"parent directory does not exist: {p.parent}"
    if p.exists() and not p.is_socket():
        return None, f"exists and is not a socket: {p}"

    return p, None


def install_termination_handlers():
    """Turn SIGTERM/SIGINT into SystemExit so cleanup handlers run.

    Without this the process dies immediately on SIGTERM and `finally` blocks
    never execute, which would leak qemu processes, run directories and socket
    files.
    """

    def handler(signum, _frame):
        raise SystemExit(128 + signum)

    signal.signal(signal.SIGTERM, handler)
    signal.signal(signal.SIGINT, handler)


def _read_request(conn, limit=1 << 20):
    """Read one newline-terminated JSON line straight off the socket.

    Deliberately avoids socket.makefile(). A buffered reader shared with the
    cancel watcher deadlocks: closing it waits for the internal lock that the
    watcher's blocked read is holding, so the connection is never closed and the
    client -- which only settles when the socket closes -- hangs forever. It also
    keeps socket._io_refs above zero, which makes socket.close() a no-op.
    """
    buf = bytearray()
    while b"\n" not in buf:
        try:
            chunk = conn.recv(4096)
        except OSError:
            return None
        if not chunk:
            return None
        buf += chunk
        if len(buf) > limit:
            return None
    return bytes(buf).split(b"\n", 1)[0]


def _send(conn, lock, obj):
    line = (json.dumps(obj) + "\n").encode()
    with lock:
        try:
            conn.sendall(line)
        except OSError:
            # The client went away; the command is still supervised and will be
            # torn down by the EOF watcher.
            pass


def _pump(stream, kind, conn, lock):
    """Forward one pipe to the client as it produces output."""
    fd = stream.fileno()
    try:
        while True:
            chunk = os.read(fd, _READ_SIZE)
            if not chunk:
                break
            _send(
                conn,
                lock,
                {"type": kind, "data": base64.b64encode(chunk).decode()},
            )
    except OSError:
        pass
    finally:
        try:
            stream.close()
        except OSError:
            pass


class _Supervisor:
    """Streams a child's output, and kills it on timeout or client cancel."""

    def __init__(self, proc, conn, lock):
        self.proc = proc
        self.conn = conn
        self.lock = lock
        self.cancelled = threading.Event()
        self._reaped = False
        self._kill_lock = threading.Lock()

    def _kill(self):
        # Guarded by _reaped: once the child has been waited for, its pid (and
        # therefore its process group id) may have been recycled, and killing it
        # could hit an unrelated process.
        with self._kill_lock:
            if self._reaped:
                return
            try:
                os.killpg(self.proc.pid, signal.SIGKILL)
            except (ProcessLookupError, PermissionError, OSError):
                pass

    def _watch_for_cancel(self):
        # pi half-closes the socket to cancel, and only then; see onAbort in
        # pi-remote.ts. So EOF on the read side means "stop".
        try:
            while self.conn.recv(1):
                pass
        except OSError:
            pass
        self.cancelled.set()
        self._kill()

    def run(self, timeout, report_timeout_as):
        pumps = [
            threading.Thread(
                target=_pump, args=(stream, kind, self.conn, self.lock), daemon=True
            )
            for stream, kind in (
                (self.proc.stdout, "stdout"),
                (self.proc.stderr, "stderr"),
            )
        ]
        for t in pumps:
            t.start()

        watcher = threading.Thread(target=self._watch_for_cancel, daemon=True)
        watcher.start()

        timed_out = False
        try:
            code = self.proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            self._kill()
            code = self.proc.wait()

        with self._kill_lock:
            self._reaped = True

        for t in pumps:
            t.join(timeout=5)

        if self.cancelled.is_set():
            # Nobody is listening any more.
            return

        # 124 is what coreutils `timeout` exits with, used by the ssh executor to
        # bound the command inside the box.
        if timed_out or code == 124:
            _send(
                self.conn,
                self.lock,
                {"type": "error", "message": f"timeout after {report_timeout_as}s"},
            )
        else:
            _send(self.conn, self.lock, {"type": "exit", "code": code})


def local_executor(command, timeout, conn, lock):
    """Run the command in this process's own context.

    Used by the in-sandbox agent, where "this context" is the inside of a bwrap
    sandbox.
    """
    proc = subprocess.Popen(
        ["bash", "-c", command],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        # Own process group, so a timeout or cancel takes the whole command tree
        # down rather than just the top-level shell.
        start_new_session=True,
    )
    _Supervisor(proc, conn, lock).run(timeout, int(timeout))


def make_ssh_executor(ssh_base, remote_cwd, grace=5):
    """Run commands inside a VM over an existing multiplexed ssh connection."""

    def executor(command, timeout, conn, lock):
        # The command travels base64-encoded and is decoded straight into
        # `bash -c`, so it is evaluated exactly once. Interpolating it into a
        # shell template instead would mean quoting for two levels of shell.
        payload = base64.b64encode(command.encode()).decode()
        limit = max(1, int(timeout))
        remote = (
            f"cd {shlex.quote(remote_cwd)} && "
            f"exec timeout -k {grace} {limit} "
            f'bash -c "$(printf %s {payload} | base64 -d)"'
        )

        proc = subprocess.Popen(
            [*ssh_base, "-n", remote],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            start_new_session=True,
        )

        # `timeout` inside the guest is what actually bounds the work; killing
        # ssh locally would not stop the remote process, because a non-tty exec
        # channel does not reliably deliver a signal on close. The local wait is
        # only a backstop for ssh itself wedging.
        _Supervisor(proc, conn, lock).run(limit + grace + 5, limit)

    return executor


def _handle(conn, executor):
    lock = threading.Lock()
    try:
        line = _read_request(conn)
        if line is None:
            return

        try:
            req = json.loads(line)
        except ValueError:
            _send(conn, lock, {"type": "error", "message": "malformed request"})
            return

        command = req.get("command")
        if not isinstance(command, str):
            _send(conn, lock, {"type": "error", "message": "no command supplied"})
            return

        timeout = req.get("timeout")
        if isinstance(timeout, bool) or not isinstance(timeout, (int, float)):
            timeout = DEFAULT_COMMAND_TIMEOUT
        if timeout <= 0:
            timeout = DEFAULT_COMMAND_TIMEOUT

        executor(command, float(timeout), conn, lock)
    except Exception as e:  # a bad request must not take the server down
        _send(conn, lock, {"type": "error", "message": str(e)})
    finally:
        # shutdown before close: it both sends FIN (so the client settles) and
        # wakes the cancel watcher out of its blocking recv.
        try:
            conn.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass
        conn.close()


def serve_forever(socket_path, executor):
    """Bind socket_path and serve commands until terminated.

    The socket is bound only once the caller has decided the sandbox is usable,
    so "socket exists" is a reliable readiness signal for both backends.
    """
    path = Path(socket_path)
    if path.is_socket():
        path.unlink()

    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        server.bind(str(path))
        os.chmod(path, 0o600)
        server.listen(64)

        while True:
            try:
                conn, _ = server.accept()
            except OSError:
                break
            threading.Thread(target=_handle, args=(conn, executor), daemon=True).start()
    finally:
        server.close()
        try:
            path.unlink()
        except OSError:
            pass
