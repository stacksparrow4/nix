use std::env;
use std::io::{self, Read, Write};
use std::net::Shutdown;
use std::os::unix::net::UnixStream;
use std::path::Path;
use std::process::exit;

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
                if let Some(mime) = other.strip_prefix("--type=") {
                    flags.mime = mime.to_string();
                }
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

    let mut stream = connect();
    let header = format!("copy {} {}\n", flags.selection, flags.mime);
    if stream
        .write_all(header.as_bytes())
        .and_then(|_| stream.write_all(&data))
        .is_err()
    {
        eprintln!("sprrw-clip: failed to send clipboard data");
        exit(1);
    }
    let _ = stream.shutdown(Shutdown::Write);
    let mut ack = Vec::new();
    let _ = stream.read_to_end(&mut ack);
}

fn run_paste(args: &[String]) {
    let flags = parse_flags(args);
    if flags.list {
        return run_list(args);
    }

    let mut stream = connect();
    let header = format!("paste {} {}\n", flags.selection, flags.mime);
    if stream.write_all(header.as_bytes()).is_err() {
        eprintln!("sprrw-clip: failed to request clipboard");
        exit(1);
    }
    let _ = stream.shutdown(Shutdown::Write);

    let mut out = Vec::new();
    if let Err(e) = stream.read_to_end(&mut out) {
        eprintln!("sprrw-clip: failed to read clipboard: {e}");
        exit(1);
    }

    let is_text = flags.mime.is_empty() || flags.mime.starts_with("text/");
    if flags.no_newline && is_text && out.last() == Some(&b'\n') {
        out.pop();
    }

    let _ = io::stdout().write_all(&out);
}

fn run_list(args: &[String]) {
    let flags = parse_flags(args);

    let mut stream = connect();
    let header = format!("list {}\n", flags.selection);
    if stream.write_all(header.as_bytes()).is_err() {
        eprintln!("sprrw-clip: failed to request clipboard types");
        exit(1);
    }
    let _ = stream.shutdown(Shutdown::Write);

    let mut out = Vec::new();
    if let Err(e) = stream.read_to_end(&mut out) {
        eprintln!("sprrw-clip: failed to read clipboard types: {e}");
        exit(1);
    }
    let _ = io::stdout().write_all(&out);
}

fn connect() -> UnixStream {
    let addr = env::var("SPRRW_CLIPBOARD_ADDR").unwrap_or_else(|_| {
        eprintln!("sprrw-clip: SPRRW_CLIPBOARD_ADDR is not set");
        exit(1);
    });

    let Some(path) = addr.strip_prefix("unix:") else {
        eprintln!("sprrw-clip: unsupported clipboard address '{addr}' (expected unix:<path>)");
        exit(1);
    };

    UnixStream::connect(path).unwrap_or_else(|e| {
        eprintln!("sprrw-clip: failed to connect to unix socket {path}: {e}");
        exit(1);
    })
}
