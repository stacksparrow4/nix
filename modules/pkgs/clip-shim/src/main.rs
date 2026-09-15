use std::env;
use std::io::{self, Read, Write};
use std::net::{Shutdown, TcpStream};
use std::process::exit;

fn main() {
    let mode = env::args().nth(1).unwrap_or_default();

    let addr = env::var("SPRRW_CLIPBOARD_ADDR").unwrap_or_else(|_| {
        eprintln!("sprrw-clip: SPRRW_CLIPBOARD_ADDR is not set");
        exit(1);
    });

    match mode.as_str() {
        "copy" => {
            let mut data = Vec::new();
            if let Err(e) = io::stdin().read_to_end(&mut data) {
                eprintln!("sprrw-clip: failed to read stdin: {e}");
                exit(1);
            }

            let mut conn = connect(&addr);
            if conn.write_all(b"copy\n").and_then(|_| conn.write_all(&data)).is_err() {
                eprintln!("sprrw-clip: failed to send clipboard data");
                exit(1);
            }
            let _ = conn.shutdown(Shutdown::Write);
            let mut ack = Vec::new();
            let _ = conn.read_to_end(&mut ack);
        }
        "paste" => {
            let mut conn = connect(&addr);
            if conn.write_all(b"paste\n").is_err() {
                eprintln!("sprrw-clip: failed to request clipboard");
                exit(1);
            }
            let _ = conn.shutdown(Shutdown::Write);

            let mut out = Vec::new();
            if let Err(e) = conn.read_to_end(&mut out) {
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

fn connect(addr: &str) -> TcpStream {
    let hostport = addr.strip_prefix("tcp:").unwrap_or_else(|| {
        eprintln!("sprrw-clip: unsupported clipboard address '{addr}'");
        exit(1);
    });

    let (host, port_str) = hostport.rsplit_once(':').unwrap_or_else(|| {
        eprintln!("sprrw-clip: invalid tcp address '{hostport}'");
        exit(1);
    });
    let port: u16 = port_str.parse().unwrap_or_else(|_| {
        eprintln!("sprrw-clip: invalid tcp port '{port_str}'");
        exit(1);
    });

    TcpStream::connect((host, port)).unwrap_or_else(|e| {
        eprintln!("sprrw-clip: failed to connect to tcp {host}:{port}: {e}");
        exit(1);
    })
}
