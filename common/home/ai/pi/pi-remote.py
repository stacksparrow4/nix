#!/usr/bin/env python3

import base64
import json
import os
import selectors
import shlex
import signal
import socket
import subprocess
import sys
import tempfile
import threading
import traceback

CMD_PLACEHOLDER = "<CMD>"


def send(conn, obj):
    conn.sendall((json.dumps(obj) + "\n").encode())


def recv(conn):
    buf = b""
    while 1:
        b = conn.recv(1)
        if not b:
            return None
        if b == b"\n":
            return json.loads(buf.decode())
        buf += b


def handle_connection(conn, template):
    req = recv(conn)

    command = req["command"]
    timeout = req.get("timeout") or 60

    host_cmd = template.replace(CMD_PLACEHOLDER, shlex.quote(command))

    # print(f"Executing the following command: {host_cmd}")

    proc = subprocess.Popen(
        ["bash", "-c", host_cmd],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        start_new_session=True,
    )

    timed_out = threading.Event()

    def output_thread_function():
        sel = selectors.DefaultSelector()
        sel.register(proc.stdout, selectors.EVENT_READ, "stdout")
        sel.register(proc.stderr, selectors.EVENT_READ, "stderr")

        open_streams = 2
        while open_streams > 0:
            if timed_out.is_set():
                break

            for key, _mask in sel.select(timeout=0.25):
                stream = key.fileobj
                kind = key.data
                chunk = (
                    stream.read1(65536)
                    if hasattr(stream, "read1")
                    else stream.read(65536)
                )
                if not chunk:
                    sel.unregister(stream)
                    open_streams -= 1
                    continue
                send(
                    conn,
                    {
                        "type": kind,
                        "data": base64.b64encode(chunk).decode(),
                    },
                )

    output_thread = threading.Thread(target=output_thread_function, daemon=True)
    output_thread.start()

    try:
        code = proc.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        timed_out.set()
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        code = proc.wait()

    output_thread.join()

    if timed_out.is_set():
        send(conn, {"type": "error", "message": f"timeout after {timeout}s"})
    else:
        send(conn, {"type": "exit", "code": int(code)})

    conn.close()


def serve(socket_path, template):
    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    srv.bind(socket_path)
    os.chmod(socket_path, 0o600)
    srv.listen(64)

    while 1:
        conn, _ = srv.accept()
        try:
            handle_connection(conn, template)
        except Exception as e:
            print(''.join(traceback.format_exception(type(e), e, e.__traceback__)))
            try:
                conn.close()
            except:
                pass


if __name__ == "__main__":
    if len(sys.argv) != 3:
        # Note: the second argument is internal with nix and not shown to the user
        print(f"Usage: pi-remote 'docker exec container sh -c {CMD_PLACEHOLDER}'")
        exit(1)

    sandbox_path = sys.argv[1]
    template = sys.argv[2]

    if CMD_PLACEHOLDER not in template:
        print(f"error: template must contain {CMD_PLACEHOLDER}", file=sys.stderr)
        exit(2)

    with tempfile.TemporaryDirectory() as sock_dir:
        socket_path = f"{sock_dir}/pi.sock"

        server_thread = threading.Thread(
            target=serve, args=(socket_path, template), daemon=True
        )
        server_thread.start()

        env = os.environ.copy()
        env["PIPEDIR"] = sock_dir
        subprocess.run([sandbox_path], env=env)
