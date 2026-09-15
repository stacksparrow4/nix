use std::env;
use std::io::{self, Read, Write};
use std::net::Shutdown;
use std::os::unix::net::UnixStream;
use std::process::exit;

fn main() {
    let mode = env::args().nth(1).unwrap_or_default();

    let socket = env::var("SPRRW_CLIPBOARD_SOCKET").unwrap_or_else(|_| {
        eprintln!("sprrw-clip: SPRRW_CLIPBOARD_SOCKET is not set");
        exit(1);
    });

    match mode.as_str() {
        "copy" => {
            let mut data = Vec::new();
            if let Err(e) = io::stdin().read_to_end(&mut data) {
                eprintln!("sprrw-clip: failed to read stdin: {e}");
                exit(1);
            }

            let mut stream = connect(&socket);
            if stream.write_all(b"copy\n").and_then(|_| stream.write_all(&data)).is_err() {
                eprintln!("sprrw-clip: failed to send clipboard data");
                exit(1);
            }
            let _ = stream.shutdown(Shutdown::Write);
            let mut ack = Vec::new();
            let _ = stream.read_to_end(&mut ack);
        }
        "paste" => {
            let mut stream = connect(&socket);
            if stream.write_all(b"paste\n").is_err() {
                eprintln!("sprrw-clip: failed to request clipboard");
                exit(1);
            }
            let _ = stream.shutdown(Shutdown::Write);

            let mut out = Vec::new();
            if let Err(e) = stream.read_to_end(&mut out) {
                eprintln!("sprrw-clip: failed to read clipboard: {e}");
                exit(1);
            }
            let _ = io::stdout().write_all(&out);
        }
        other => {
            eprintln!("sprrw-clip: unknown mode '{other}' (expected 'copy' or 'paste')");
            exit(2);
        }
    }
}

fn connect(path: &str) -> UnixStream {
    UnixStream::connect(path).unwrap_or_else(|e| {
        eprintln!("sprrw-clip: failed to connect to {path}: {e}");
        exit(1);
    })
}
