use std::env;
use std::io::{self, Read, Write};
use std::net::{Shutdown, TcpStream};
use std::os::unix::net::UnixStream;
use std::path::Path;
use std::process::exit;

/// A clipboard bridge client. It is installed under several names (`wl-copy`,
/// `wl-paste`, and `sprrw-clip`) and figures out what to do from its own
/// argv[0] plus the usual flags those tools accept, then forwards the request
/// over a socket to the host-side bridge started by `box --clipboard`.
///
/// Wire protocol (newline terminated header, then an optional raw payload):
///   copy  <sel> <mime>\n<bytes...>   -> server writes bytes to the clipboard
///   paste <sel> <mime>\n             -> server replies with the raw bytes
///   list  <sel>\n                    -> server replies with newline separated mimes
/// where <sel> is `c` (clipboard) or `p` (primary) and <mime> may be empty.
fn main() {
    let prog = env::args()
        .next()
        .map(|a| {
            Path::new(&a)
                .file_name()
                .map(|f| f.to_string_lossy().into_owned())
                .unwrap_or(a)
        })
        .unwrap_or_default();

    let args: Vec<String> = env::args().skip(1).collect();

    match prog.as_str() {
        "wl-copy" => run_copy(&args),
        "wl-paste" => run_paste(&args),
        // Legacy / explicit invocation: `sprrw-clip <copy|paste|list> [flags]`.
        "sprrw-clip" => match args.first().map(String::as_str) {
            Some("copy") => run_copy(&args[1..]),
            Some("paste") => run_paste(&args[1..]),
            Some("list") => run_list(&args[1..]),
            other => {
                eprintln!("sprrw-clip: unknown mode {other:?} (expected copy|paste|list)");
                exit(2);
            }
        },
        other => {
            eprintln!("sprrw-clip: invoked under unexpected name '{other}'");
            exit(2);
        }
    }
}

struct Flags {
    selection: char,
    mime: String,
    no_newline: bool,
    list: bool,
    clear: bool,
}

fn parse_flags(args: &[String]) -> Flags {
    let mut flags = Flags {
        selection: 'c',
        mime: String::new(),
        no_newline: false,
        list: false,
        clear: false,
    };

    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "-p" | "--primary" => flags.selection = 'p',
            "-n" | "--no-newline" => flags.no_newline = true,
            "-l" | "--list-types" => flags.list = true,
            "-c" | "--clear" => flags.clear = true,
            "-t" | "--type" => {
                i += 1;
                if let Some(mime) = args.get(i) {
                    flags.mime = mime.clone();
                }
            }
            other => {
                // wl-copy/wl-paste accept `--type=mime` too.
                if let Some(mime) = other.strip_prefix("--type=") {
                    flags.mime = mime.to_string();
                }
                // Everything else (e.g. --foreground, --trim-newline) is ignored.
            }
        }
        i += 1;
    }

    flags
}

fn run_copy(args: &[String]) {
    let flags = parse_flags(args);

    let data = if flags.clear {
        Vec::new()
    } else {
        let mut buf = Vec::new();
        if let Err(e) = io::stdin().read_to_end(&mut buf) {
            eprintln!("sprrw-clip: failed to read stdin: {e}");
            exit(1);
        }
        buf
    };

    let mut conn = connect();
    let header = format!("copy {} {}\n", flags.selection, flags.mime);
    if conn
        .write_all(header.as_bytes())
        .and_then(|_| conn.write_all(&data))
        .is_err()
    {
        eprintln!("sprrw-clip: failed to send clipboard data");
        exit(1);
    }
    conn.shutdown_write();
    let mut ack = Vec::new();
    let _ = conn.read_to_end(&mut ack);
}

fn run_paste(args: &[String]) {
    let flags = parse_flags(args);
    if flags.list {
        return run_list(args);
    }

    let mut conn = connect();
    let header = format!("paste {} {}\n", flags.selection, flags.mime);
    if conn.write_all(header.as_bytes()).is_err() {
        eprintln!("sprrw-clip: failed to request clipboard");
        exit(1);
    }
    conn.shutdown_write();

    let mut out = Vec::new();
    if let Err(e) = conn.read_to_end(&mut out) {
        eprintln!("sprrw-clip: failed to read clipboard: {e}");
        exit(1);
    }

    // `--no-newline` only ever strips a single trailing newline from text; never
    // touch binary payloads (e.g. image/png) where a trailing 0x0a is data.
    let is_text = flags.mime.is_empty() || flags.mime.starts_with("text/");
    if flags.no_newline && is_text && out.last() == Some(&b'\n') {
        out.pop();
    }

    let _ = io::stdout().write_all(&out);
}

fn run_list(args: &[String]) {
    let flags = parse_flags(args);

    let mut conn = connect();
    let header = format!("list {}\n", flags.selection);
    if conn.write_all(header.as_bytes()).is_err() {
        eprintln!("sprrw-clip: failed to request clipboard types");
        exit(1);
    }
    conn.shutdown_write();

    let mut out = Vec::new();
    if let Err(e) = conn.read_to_end(&mut out) {
        eprintln!("sprrw-clip: failed to read clipboard types: {e}");
        exit(1);
    }
    let _ = io::stdout().write_all(&out);
}

enum Conn {
    Unix(UnixStream),
    Tcp(TcpStream),
}

impl Conn {
    fn shutdown_write(&self) {
        let _ = match self {
            Conn::Unix(s) => s.shutdown(Shutdown::Write),
            Conn::Tcp(s) => s.shutdown(Shutdown::Write),
        };
    }
}

impl Read for Conn {
    fn read(&mut self, buf: &mut [u8]) -> io::Result<usize> {
        match self {
            Conn::Unix(s) => s.read(buf),
            Conn::Tcp(s) => s.read(buf),
        }
    }
}

impl Write for Conn {
    fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
        match self {
            Conn::Unix(s) => s.write(buf),
            Conn::Tcp(s) => s.write(buf),
        }
    }
    fn flush(&mut self) -> io::Result<()> {
        match self {
            Conn::Unix(s) => s.flush(),
            Conn::Tcp(s) => s.flush(),
        }
    }
}

fn connect() -> Conn {
    let addr = env::var("SPRRW_CLIPBOARD_ADDR").unwrap_or_else(|_| {
        eprintln!("sprrw-clip: SPRRW_CLIPBOARD_ADDR is not set");
        exit(1);
    });

    if let Some(path) = addr.strip_prefix("unix:") {
        return Conn::Unix(UnixStream::connect(path).unwrap_or_else(|e| {
            eprintln!("sprrw-clip: failed to connect to unix socket {path}: {e}");
            exit(1);
        }));
    }

    if let Some(hostport) = addr.strip_prefix("tcp:") {
        let (host, port_str) = hostport.rsplit_once(':').unwrap_or_else(|| {
            eprintln!("sprrw-clip: invalid tcp address '{hostport}'");
            exit(1);
        });
        let port: u16 = port_str.parse().unwrap_or_else(|_| {
            eprintln!("sprrw-clip: invalid tcp port '{port_str}'");
            exit(1);
        });
        return Conn::Tcp(TcpStream::connect((host, port)).unwrap_or_else(|e| {
            eprintln!("sprrw-clip: failed to connect to tcp {host}:{port}: {e}");
            exit(1);
        }));
    }

    eprintln!("sprrw-clip: unsupported clipboard address '{addr}'");
    exit(1);
}
