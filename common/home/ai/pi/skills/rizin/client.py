#!/usr/bin/env python3
import argparse
import socket


def main():
    parser = argparse.ArgumentParser(description="Send a command to a rizin unix socket server")
    parser.add_argument("socket_path", help="Path to the unix socket")
    parser.add_argument("command", help="Rizin command to execute")
    args = parser.parse_args()

    conn = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    conn.connect(args.socket_path)

    conn.sendall(args.command.encode("utf-8"))
    conn.shutdown(socket.SHUT_WR)

    result = b""
    while True:
        chunk = conn.recv(4096)
        if not chunk:
            break
        result += chunk

    conn.close()
    print(result.decode("utf-8"))


if __name__ == "__main__":
    main()
