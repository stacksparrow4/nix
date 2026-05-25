#!/usr/bin/env python3-rzpipe
import argparse
import os
import socket
import sys
import rzpipe


def create_socket():
    socket_path = f"/tmp/rizin-{os.getpid()}.sock"

    if os.path.exists(socket_path):
        os.unlink(socket_path)

    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(socket_path)
    server.listen(1)

    return server, socket_path


def main(program: str, server: socket.socket, socket_path: str):
    rz = rzpipe.open(program)
    rz.cmd("aaa")

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
                result = rz.cmd(command)
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
    args = parser.parse_args()

    server, socket_path = create_socket()
    print(socket_path, flush=True)

    pid = os.fork()
    if pid > 0:
        sys.exit(0)

    os.setsid()
    main(args.program, server, socket_path)
