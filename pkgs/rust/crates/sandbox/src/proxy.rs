//! Shuttles stdin/stdout to a unix socket, as ssh's ProxyCommand.

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

    let _ = from_socket.shutdown(Shutdown::Both);
    drop(pump);
    0
}
