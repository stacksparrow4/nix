use std::env;
use std::ffi::CString;
use std::fs;
use std::io::{BufRead, BufReader, Write};
use std::os::unix::io::{AsRawFd, RawFd};
use std::os::unix::net::UnixStream;
use std::process::exit;
use std::sync::atomic::{AtomicI32, Ordering};

use clap::{Parser, Subcommand};

/// Thin control client for the Pi subagent system.
#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Args {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand, Debug)]
enum Command {
    /// Launch a subagent, daemonize, and stream its event log
    Run {
        /// The task for the subagent to perform
        #[arg(required = true, num_args = 1.., trailing_var_arg = true)]
        task: Vec<String>,
    },
    /// Block until subagent N finishes
    Wait {
        /// The subagent id (or a subagent-<N>.log path)
        id: String,
    },
}

fn log_path(id: &str) -> String {
    format!("/tmp/subagent-{}.log", id)
}

fn pid_path(id: &str) -> String {
    format!("/tmp/subagent-{}.pid", id)
}

fn main() {
    let args = Args::parse();
    match args.command {
        Command::Run { task } => run(task),
        Command::Wait { id } => wait(id),
    }
}

fn run(task: Vec<String>) {
    let socket = match env::var("PI_SUBAGENT_SOCKET") {
        Ok(s) if !s.is_empty() => s,
        _ => {
            eprintln!("subagents unavailable in this context");
            exit(1);
        }
    };

    let task = task.join(" ");
    if task.trim().is_empty() {
        eprintln!("usage: subagent run <task...>");
        exit(2);
    }

    let cwd = env::current_dir()
        .map(|p| p.to_string_lossy().to_string())
        .unwrap_or_default();

    let stream = UnixStream::connect(&socket).unwrap_or_else(|e| {
        eprintln!("subagent: failed to connect to control socket ({socket}): {e}");
        exit(1);
    });

    let mut writer = stream.try_clone().expect("failed to clone control socket");
    let mut reader = BufReader::new(stream);

    let req = format!(
        "{{\"type\":\"run\",\"task\":\"{}\",\"cwd\":\"{}\"}}\n",
        json_escape(&task),
        json_escape(&cwd),
    );
    if writer.write_all(req.as_bytes()).is_err() || writer.flush().is_err() {
        eprintln!("subagent: failed to send request to control server");
        exit(1);
    }

    let mut line = String::new();
    if reader.read_line(&mut line).unwrap_or(0) == 0 {
        eprintln!("subagent: no response from control server");
        exit(1);
    }
    let line = line.trim();

    if line.contains("\"type\":\"error\"") {
        let msg = json_field(line, "message").unwrap_or_else(|| "unknown error".to_string());
        eprintln!("subagent: {msg}");
        exit(1);
    }

    let id = match json_field(line, "id") {
        Some(v) => v,
        None => {
            eprintln!("subagent: bad response from control server: {line}");
            exit(1);
        }
    };
    let path = json_field(line, "logPath").unwrap_or_else(|| log_path(&id));

    println!("Agent started. Log at {path}");
    let _ = std::io::stdout().flush();

    daemonize();

    writer_loop(reader, &id, &path);
}

fn writer_loop(mut reader: BufReader<UnixStream>, id: &str, path: &str) {
    set_proc_name(id);

    let pidfile = pid_path(id);
    let _ = fs::write(&pidfile, format!("{}\n", std::process::id()));

    let mut log = match fs::OpenOptions::new().create(true).append(true).open(path) {
        Ok(f) => f,
        Err(_) => {
            let _ = fs::remove_file(&pidfile);
            exit(1);
        }
    };

    install_sigterm_handler(log.as_raw_fd(), &pidfile);

    let mut line = String::new();
    loop {
        line.clear();
        match reader.read_line(&mut line) {
            Ok(0) => break,
            Err(_) => break,
            Ok(_) => {
                let _ = log.write_all(line.as_bytes());
                let _ = log.flush();
                if line.contains("\"type\":\"subagent_end\"") {
                    break;
                }
            }
        }
    }

    let _ = fs::remove_file(&pidfile);
    exit(0);
}

fn wait(id: String) {
    let id_str = id
        .trim_start_matches("subagent-")
        .trim_end_matches(".log")
        .to_string();

    let id_num: i64 = match id_str.parse() {
        Ok(n) => n,
        Err(_) => {
            eprintln!("subagent: invalid id: {id_str}");
            exit(2);
        }
    };

    let socket = match env::var("PI_SUBAGENT_SOCKET") {
        Ok(s) if !s.is_empty() => s,
        _ => {
            eprintln!("subagents unavailable in this context");
            exit(1);
        }
    };

    let stream = UnixStream::connect(&socket).unwrap_or_else(|e| {
        eprintln!("subagent: failed to connect to control socket ({socket}): {e}");
        exit(1);
    });

    let mut writer = stream.try_clone().expect("failed to clone control socket");
    let mut reader = BufReader::new(stream);

    let req = format!("{{\"type\":\"wait\",\"id\":{id_num}}}\n");
    if writer.write_all(req.as_bytes()).is_err() || writer.flush().is_err() {
        eprintln!("subagent: failed to send request to control server");
        exit(1);
    }

    let mut line = String::new();
    if reader.read_line(&mut line).unwrap_or(0) == 0 {
        eprintln!("subagent: no response from control server");
        exit(1);
    }
    let line = line.trim();

    if line.contains("\"type\":\"error\"") {
        let msg = json_field(line, "message").unwrap_or_else(|| "unknown error".to_string());
        eprintln!("subagent: {msg}");
        exit(4);
    }

    if line.contains("\"type\":\"subagent_end\"") {
        if line.contains("\"aborted\":true") {
            eprintln!("subagent {id_num}: aborted");
        }
        let code = json_field(line, "exitCode")
            .and_then(|v| v.parse::<i32>().ok())
            .unwrap_or(0);
        exit(code);
    }

    eprintln!("subagent: unexpected response from control server: {line}");
    exit(1);
}

fn daemonize() {
    unsafe {
        match libc::fork() {
            -1 => {
                eprintln!("subagent: fork failed");
                exit(1);
            }
            0 => {}
            _ => exit(0),
        }

        if libc::setsid() == -1 {
            exit(1);
        }

        match libc::fork() {
            -1 => exit(1),
            0 => {}
            _ => exit(0),
        }

        redirect_std_to_null();
    }
}

unsafe fn redirect_std_to_null() {
    let devnull = CString::new("/dev/null").unwrap();
    let fd = unsafe { libc::open(devnull.as_ptr(), libc::O_RDWR) };
    if fd < 0 {
        return;
    }
    unsafe {
        libc::dup2(fd, libc::STDIN_FILENO);
        libc::dup2(fd, libc::STDOUT_FILENO);
        libc::dup2(fd, libc::STDERR_FILENO);
        if fd > libc::STDERR_FILENO {
            libc::close(fd);
        }
    }
}

fn set_proc_name(id: &str) {
    let mut name = format!("subagent[{id}]").into_bytes();
    name.truncate(15);
    name.push(0);
    unsafe {
        libc::prctl(
            libc::PR_SET_NAME,
            name.as_ptr() as libc::c_ulong,
            0 as libc::c_ulong,
            0 as libc::c_ulong,
            0 as libc::c_ulong,
        );
    }
}

static SIG_LOG_FD: AtomicI32 = AtomicI32::new(-1);
static mut SIG_PIDFILE: Option<CString> = None;

fn install_sigterm_handler(log_fd: RawFd, pidfile: &str) {
    SIG_LOG_FD.store(log_fd, Ordering::SeqCst);
    unsafe {
        SIG_PIDFILE = Some(CString::new(pidfile).unwrap());
        libc::signal(libc::SIGTERM, on_sigterm as *const () as libc::sighandler_t);
    }
}

extern "C" fn on_sigterm(_sig: libc::c_int) {
    let marker = b"{\"type\":\"subagent_end\",\"aborted\":true}\n";
    let fd = SIG_LOG_FD.load(Ordering::SeqCst);
    if fd >= 0 {
        unsafe {
            libc::write(fd, marker.as_ptr() as *const libc::c_void, marker.len());
        }
    }
    unsafe {
        #[allow(static_mut_refs)]
        if let Some(pf) = SIG_PIDFILE.as_ref() {
            libc::unlink(pf.as_ptr());
        }
        libc::_exit(0);
    }
}

fn json_escape(s: &str) -> String {
    let mut out = String::with_capacity(s.len() + 2);
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out
}

fn json_field(line: &str, key: &str) -> Option<String> {
    let needle = format!("\"{key}\"");
    let start = line.find(&needle)? + needle.len();
    let rest = &line[start..];
    let colon = rest.find(':')?;
    let mut chars = rest[colon + 1..].char_indices().peekable();

    while let Some(&(_, c)) = chars.peek() {
        if c.is_whitespace() {
            chars.next();
        } else {
            break;
        }
    }

    let after_ws = &rest[colon + 1..];
    let ws_len = after_ws.len() - after_ws.trim_start().len();
    let value = after_ws[ws_len..].to_string();

    if let Some(stripped) = value.strip_prefix('"') {
        let mut out = String::new();
        let mut escaped = false;
        for c in stripped.chars() {
            if escaped {
                out.push(match c {
                    'n' => '\n',
                    'r' => '\r',
                    't' => '\t',
                    other => other,
                });
                escaped = false;
            } else if c == '\\' {
                escaped = true;
            } else if c == '"' {
                return Some(out);
            } else {
                out.push(c);
            }
        }
        Some(out)
    } else {
        let end = value
            .find(|c: char| c == ',' || c == '}' || c.is_whitespace())
            .unwrap_or(value.len());
        Some(value[..end].to_string())
    }
}
