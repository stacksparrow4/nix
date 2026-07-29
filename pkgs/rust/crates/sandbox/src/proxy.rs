//! Shuttle stdin/stdout to a unix socket.
//!
//! Used as ssh's ProxyCommand so that reaching the VM's forwarded sshd needs no
//! external forwarder. This replaces `socat - UNIX-CONNECT:...`, which was the
//! only reason socat was in this package's closure.

use std::{
    io::{Read, Write},
    net::Shutdown,
    os::unix::net::UnixStream,
    path::Path,
    thread,
};

pub fn run(socket: &Path) -> i32 {
    let stream = match UnixStream::connect(socket) {
        Ok(stream) => stream,
        Err(e) => {
            eprintln!("Could not connect to {}: {e}", socket.display());
            return 1;
        }
    };

    let mut to_socket = match stream.try_clone() {
        Ok(clone) => clone,
        Err(e) => {
            eprintln!("Could not clone socket: {e}");
            return 1;
        }
    };
    let mut from_socket = stream;

    // stdin -> socket on a second thread; socket -> stdout on this one. Each
    // direction shuts down its half when it hits EOF so the peer notices.
    let pump = thread::spawn(move || {
        let mut stdin = std::io::stdin().lock();
        let mut buf = [0u8; 65536];
        loop {
            match stdin.read(&mut buf) {
                Ok(0) | Err(_) => break,
                Ok(n) => {
                    if to_socket.write_all(&buf[..n]).is_err() {
                        break;
                    }
                }
            }
        }
        let _ = to_socket.shutdown(Shutdown::Write);
    });

    let mut stdout = std::io::stdout().lock();
    let mut buf = [0u8; 65536];
    loop {
        match from_socket.read(&mut buf) {
            Ok(0) | Err(_) => break,
            Ok(n) => {
                if stdout.write_all(&buf[..n]).is_err() {
                    break;
                }
                let _ = stdout.flush();
            }
        }
    }

    // ssh has closed the connection; do not wait for a stdin read that may never
    // return.
    let _ = from_socket.shutdown(Shutdown::Both);
    drop(pump);
    0
}
