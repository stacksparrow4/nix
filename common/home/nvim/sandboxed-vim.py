#!/usr/bin/env python3

import sys
import subprocess
import os
import socket
import tempfile
import threading
import select

end_bwrap_args_ind = sys.argv.index("ENDBWRAPARGS")

additional_bwrap_args = sys.argv[1:end_bwrap_args_ind]
vim_path = sys.argv[end_bwrap_args_ind + 1]
vim_args = sys.argv[end_bwrap_args_ind + 2 :]


with tempfile.TemporaryDirectory() as tmpdir:
    finish_r, finish_w = os.pipe()

    def copy_thread():
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as server:
            server.bind(f"{tmpdir}/copy.sock")
            server.listen(1)

            running = True

            while running:
                readable, _, _ = select.select([server, finish_r], [], [])

                if finish_r in readable:
                    running = False
                    break

                if server in readable:
                    conn, _ = server.accept()

                    copy_data = b""

                    with conn:
                        while running:
                            readable, _, _ = select.select([conn, finish_r], [], [])

                            if finish_r in readable:
                                running = False
                                break

                            data = conn.recv(4096)
                            if data == b"":
                                break

                            copy_data += data

                    subprocess.run(["wl-copy"], input=copy_data)

    def paste_thread():
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as server:
            server.bind(f"{tmpdir}/paste.sock")
            server.listen(1)

            running = True

            while running:
                readable, _, _ = select.select([server, finish_r], [], [])

                if finish_r in readable:
                    running = False
                    break

                if server in readable:
                    conn, _ = server.accept()

                    data_to_send = subprocess.run(
                        ["wl-paste", "-n"], stdout=subprocess.PIPE
                    ).stdout

                    with conn:
                        while len(data_to_send) != 0:
                            readable, _, _ = select.select([finish_r], [conn], [])

                            if finish_r in readable:
                                running = False
                                break

                            amnt_sent = conn.send(data_to_send)

                            if amnt_sent == 0:
                                break

                            data_to_send = data_to_send[amnt_sent:]

    t_copy = threading.Thread(target=copy_thread)
    t_copy.start()

    t_paste = threading.Thread(target=paste_thread)
    t_paste.start()

    additional_bwrap_args = [*additional_bwrap_args, "--bind", tmpdir, "/tmp/copypaste"]
    additional_vim_args = [
        "-c",
        "lua vim.g.clipboard = { name = 'customClip', copy = { ['+'] = 'socat - UNIX-CONNECT:/tmp/copypaste/copy.sock' }, paste = { ['+'] = 'socat - UNIX-CONNECT:/tmp/copypaste/paste.sock' } }",
    ]

    proc_args = None

    default_bwrap_args = [
        "bwrap",
        "--unshare-all",
        "--as-pid-1",
        *["--ro-bind", "/nix", "/nix"],
        *["--ro-bind", "/etc", "/etc"],
        *["--ro-bind", "/usr", "/usr"],
        *["--ro-bind", "/run/current-system/sw", "/run/current-system/sw"],
        *["--ro-bind", "/home/sprrw/.config/nvim", "/home/sprrw/.config/nvim"],
        *["--tmpfs", "/tmp"],
        *["--proc", "/proc"],
        *["--dev", "/dev"],
    ]

    share_dir = os.getcwd()
    if len(vim_args) == 1 and vim_args[0].startswith("/"):
        arg = vim_args[0]
        if os.path.isdir(arg):
            share_dir = arg
            share_file = "."
        else:
            share_dir = os.path.dirname(arg)
            share_file = os.path.basename(arg)

        additional_vim_args.append(share_file)
    else:
        additional_vim_args.extend(vim_args)

    args = [
        *default_bwrap_args,
        *["--bind", share_dir, share_dir],
        *additional_bwrap_args,
        "/usr/bin/env",
        "PATH=/etc/hm-package/home-path/bin:/run/current-system/sw/bin",
        vim_path,
        *additional_vim_args,
    ]

    exit_code = subprocess.call(args, cwd=share_dir)

    os.write(finish_w, b"\x00")

exit(exit_code)
