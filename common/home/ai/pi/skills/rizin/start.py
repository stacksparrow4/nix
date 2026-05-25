#!/usr/bin/env python3
import argparse
import os
import socket
import sys
from rzopen import RzPipe, RzPipeError


def create_socket():
    socket_path = f"/tmp/rizin-{os.getpid()}.sock"

    if os.path.exists(socket_path):
        os.unlink(socket_path)

    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(socket_path)
    server.listen(1)

    return server, socket_path


def main(rz, server, socket_path):
    try:
        while True:
            conn, _ = server.accept()
            try:
                data = b""
                while True:
                    chunk = conn.recv(4096)
                    if not chunk:
                        break
                    data += chunk
                command = data.decode("utf-8").strip()
                if command == "exit":
                    break
                try:
                    result = rz.cmd(command)
                except RzPipeError as e:
                    result = str(e)
                conn.sendall(result.encode("utf-8"))
            finally:
                conn.close()
    finally:
        server.close()
        os.unlink(socket_path)
        rz.quit()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Open a program in rizin and listen for commands on a unix socket")
    parser.add_argument("program", help="Path to the program to load in rizin")
    parser.add_argument("--no-fork", action="store_true", help="Run in foreground (don't fork)")
    args = parser.parse_args()

    if args.no_fork:
        server, socket_path = create_socket()

        try:
            rz = RzPipe(args.program)
        except RzPipeError as e:
            print(f"Error opening program: {e}", file=sys.stderr)
            server.close()
            os.unlink(socket_path)
            sys.exit(1)

        try:
            rz.cmd("aaa")
        except RzPipeError as e:
            print(f"Error during analysis: {e}", file=sys.stderr)
            rz.quit()
            server.close()
            os.unlink(socket_path)
            sys.exit(1)

        print(socket_path, flush=True)
        main(rz, server, socket_path)
    else:
        # Fork first, then open rizin in the child to avoid
        # rizin's subprocess dying when the parent exits.
        # Use a pipe to communicate status back to the parent.
        status_r, status_w = os.pipe()

        pid = os.fork()
        if pid > 0:
            # Parent: wait for child to report success or failure
            os.close(status_w)
            msg = b""
            while True:
                chunk = os.read(status_r, 4096)
                if not chunk:
                    break
                msg += chunk
            os.close(status_r)
            msg = msg.decode("utf-8")
            if msg.startswith("OK:"):
                print(msg[3:], flush=True)
                os._exit(0)
            else:
                print(msg, file=sys.stderr, flush=True)
                os._exit(1)

        # Child: detach and do all rizin work
        os.close(status_r)
        os.setsid()

        server, socket_path = create_socket()

        try:
            rz = RzPipe(args.program)
        except RzPipeError as e:
            os.write(status_w, f"Error opening program: {e}".encode())
            os.close(status_w)
            server.close()
            os.unlink(socket_path)
            os._exit(1)

        try:
            rz.cmd("aaa")
        except RzPipeError as e:
            os.write(status_w, f"Error during analysis: {e}".encode())
            os.close(status_w)
            rz.quit()
            server.close()
            os.unlink(socket_path)
            os._exit(1)

        # Signal success to parent
        os.write(status_w, f"OK:{socket_path}".encode())
        os.close(status_w)

        main(rz, server, socket_path)
