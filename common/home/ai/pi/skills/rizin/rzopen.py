#!/usr/bin/env python3
"""Minimal rzpipe replacement with proper error handling.

Spawns a rizin subprocess with stdin/stdout/stderr pipes.
Errors are captured from stderr and raised as exceptions
instead of being silently printed or causing hangs.
"""

import os
import fcntl
import time
from subprocess import Popen, PIPE


class RzPipeError(Exception):
    pass


class RzPipe:
    def __init__(self, filename, flags=None):
        if flags is None:
            flags = []
        cmd = ["rizin", "-q0"] + flags + [filename]
        self.process = Popen(
            cmd, shell=False, stdin=PIPE, stdout=PIPE, stderr=PIPE, bufsize=0
        )
        # Make stdout and stderr non-blocking
        self._make_non_blocking(self.process.stdout.fileno())
        self._make_non_blocking(self.process.stderr.fileno())
        # Wait for the initial \x00 indicating rizin is ready
        self._wait_for_ready()

    @staticmethod
    def _make_non_blocking(fd):
        fl = fcntl.fcntl(fd, fcntl.F_GETFL)
        fcntl.fcntl(fd, fcntl.F_SETFL, fl | os.O_NONBLOCK)

    def _read_stderr(self):
        """Read all available stderr output."""
        err = b""
        try:
            while True:
                chunk = self.process.stderr.read(4096)
                if not chunk:
                    break
                err += chunk
        except (BlockingIOError, OSError):
            pass
        return err.decode("utf-8", errors="ignore")

    def _wait_for_ready(self):
        """Wait for rizin to send the initial \\x00 byte on stdout."""
        out = b""
        while True:
            if self.process.poll() is not None:
                # Process exited before becoming ready
                err = self._read_stderr()
                raise RzPipeError(
                    err.strip() if err.strip() else
                    f"rizin exited with code {self.process.returncode}"
                )
            try:
                chunk = self.process.stdout.read(1024)
                if chunk:
                    if b"\x00" in chunk:
                        return
                    out += chunk
            except (BlockingIOError, OSError):
                pass
            time.sleep(0.01)

    def cmd(self, command):
        """Send a command to rizin and return the result string.

        Raises RzPipeError if rizin writes to stderr or the process dies.
        """
        if self.process.poll() is not None:
            raise RzPipeError("rizin process is no longer running")

        command = command.strip().replace("\n", ";")
        self.process.stdin.write((command + "\n").encode("utf-8"))
        self.process.stdin.flush()

        out = b""
        while True:
            if self.process.poll() is not None:
                # Process died mid-command
                err = self._read_stderr()
                raise RzPipeError(
                    err.strip() if err.strip() else
                    f"rizin exited with code {self.process.returncode}"
                )
            try:
                chunk = self.process.stdout.read(4096)
                if chunk:
                    if chunk.endswith(b"\x00"):
                        out += chunk[:-1]
                        break
                    out += chunk
                    continue
            except (BlockingIOError, OSError):
                pass
            time.sleep(0.001)

        result = out.decode("utf-8", errors="ignore")

        # Check stderr for errors (rizin prefixes real errors with ERROR)
        err = self._read_stderr()
        if "ERROR" in err.upper():
            raise RzPipeError(err.strip())

        return result

    def quit(self):
        """Terminate the rizin process."""
        if hasattr(self, "process") and self.process.poll() is None:
            try:
                self.process.stdin.write(b"q\n")
                self.process.stdin.flush()
            except (BrokenPipeError, OSError):
                pass
            try:
                self.process.wait(timeout=5)
            except Exception:
                self.process.kill()
                self.process.wait()
        for f in [self.process.stdin, self.process.stdout, self.process.stderr]:
            if f:
                try:
                    f.close()
                except Exception:
                    pass

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.quit()
