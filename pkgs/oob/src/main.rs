//! oob - a thin wrapper around `interactsh`.
//!
//! It runs interactsh in JSON mode, parses the JSON-lines interaction
//! stream, and re-displays only a focused subset of the data:
//!
//!   * the interactsh-generated URL (e.g. blah.oast.live)
//!   * the date and time of each interaction
//!   * the interaction type (DNS, HTTP, SMTP, ...)
//!   * for HTTP/HTTPS interactions, the full raw HTTP *request* (never the
//!     response)
//!
//! Nothing else that interactsh normally prints is shown.

use std::collections::hash_map::DefaultHasher;
use std::env;
use std::fs;
use std::hash::{Hash, Hasher};
use std::io::{BufRead, BufReader};
use std::process::{Command, Stdio};
use std::thread;
use std::time::{Duration, Instant};

use chrono::{DateTime, Local, Utc};
use serde::Deserialize;

/// One interaction record as emitted by interactsh `-json`.
#[derive(Debug, Deserialize)]
struct Interaction {
    protocol: String,
    #[serde(default)]
    #[serde(rename = "unique-id")]
    unique_id: String,
    #[serde(default)]
    #[serde(rename = "full-id")]
    full_id: String,
    #[serde(default)]
    #[serde(rename = "q-type")]
    q_type: Option<String>,
    #[serde(default)]
    #[serde(rename = "raw-request")]
    raw_request: Option<String>,
    #[serde(default)]
    timestamp: Option<String>,
    // Note: `raw-response`, `remote-address`, etc. are intentionally ignored.
}

/// The interactsh binary. Always called `interactsh` and resolved via PATH.
const INTERACTSH_BIN: &str = "interactsh";

/// Format an RFC3339 timestamp into a friendly string in the local timezone.
fn fmt_time(ts: &Option<String>) -> String {
    match ts {
        Some(raw) => match raw.parse::<DateTime<Utc>>() {
            Ok(dt) => dt
                .with_timezone(&Local)
                .format("%Y-%m-%d %H:%M:%S")
                .to_string(),
            Err(_) => raw.clone(),
        },
        None => "<no timestamp>".to_string(),
    }
}

/// Convert an HSL colour (h in [0,360), s/l in [0,1]) to 8-bit RGB.
fn hsl_to_rgb(h: f64, s: f64, l: f64) -> (u8, u8, u8) {
    let c = (1.0 - (2.0 * l - 1.0).abs()) * s;
    let h_prime = h / 60.0;
    let x = c * (1.0 - (h_prime % 2.0 - 1.0).abs());
    let (r1, g1, b1) = match h_prime as u32 {
        0 => (c, x, 0.0),
        1 => (x, c, 0.0),
        2 => (0.0, c, x),
        3 => (0.0, x, c),
        4 => (x, 0.0, c),
        _ => (c, 0.0, x),
    };
    let m = l - c / 2.0;
    let to_u8 = |v: f64| ((v + m) * 255.0).round().clamp(0.0, 255.0) as u8;
    (to_u8(r1), to_u8(g1), to_u8(b1))
}

/// Wrap a timestamp string in a 24-bit ANSI colour whose hue is derived from a
/// hash of the string. Saturation and lightness are fixed so different times
/// are easy to tell apart at a glance while staying readable.
fn colorize_timestamp(when: &str) -> String {
    let mut hasher = DefaultHasher::new();
    when.hash(&mut hasher);
    let hue = (hasher.finish() % 360) as f64;
    let (r, g, b) = hsl_to_rgb(hue, 0.65, 0.6);
    format!("\x1b[38;2;{r};{g};{b}m[{when}]\x1b[0m")
}

fn main() {
    // Forward any extra args the user passes (e.g. -n, -s, -sf) straight to
    // interactsh-client. We strip a leading "--" separator if present.
    let mut user_args: Vec<String> = env::args().skip(1).collect();
    if user_args.first().map(|s| s == "--").unwrap_or(false) {
        user_args.remove(0);
    }

    if user_args.iter().any(|a| a == "-h" || a == "--help" || a == "-help") {
        print_help();
        return;
    }

    // Temp file where interactsh writes the generated payload(s).
    let payload_file = env::temp_dir().join(format!("oob-payloads-{}.txt", std::process::id()));
    let _ = fs::remove_file(&payload_file);

    // Build the argument list. We always force JSON output (parsed from stdout)
    // and ask interactsh to store the generated payloads so we can show them.
    let mut args: Vec<String> = vec![
        "-json".to_string(),
        "-ps".to_string(),
        "-psf".to_string(),
        payload_file.to_string_lossy().into_owned(),
    ];
    args.extend(user_args);

    let mut child = match Command::new(INTERACTSH_BIN)
        .args(&args)
        .stdout(Stdio::piped())
        // Discard interactsh's banner / INF log lines so our output stays clean.
        .stderr(Stdio::null())
        .spawn()
    {
        Ok(c) => c,
        Err(e) => {
            eprintln!("oob: failed to launch '{INTERACTSH_BIN}': {e}");
            eprintln!("oob: ensure '{INTERACTSH_BIN}' is installed and on your PATH.");
            std::process::exit(1);
        }
    };

    // In a background thread, wait for interactsh to write the payload file,
    // then print the generated URL(s). This races with the first interactions,
    // which is fine: payloads are written before interactions can arrive.
    let pf = payload_file.clone();
    let payload_thread = thread::spawn(move || -> Vec<String> {
        let deadline = Instant::now() + Duration::from_secs(30);
        loop {
            if let Ok(contents) = fs::read_to_string(&pf) {
                let urls: Vec<String> = contents
                    .lines()
                    .map(|l| l.trim())
                    .filter(|l| !l.is_empty())
                    .map(|l| l.to_string())
                    .collect();
                if !urls.is_empty() {
                    for u in &urls {
                        println!("{u}");
                    }
                    println!();
                    return urls;
                }
            }
            if Instant::now() >= deadline {
                return Vec::new();
            }
            thread::sleep(Duration::from_millis(200));
        }
    });

    // Derive the server domain suffix once payloads are known, so we can
    // reconstruct the full host per interaction (handles subdomain prefixes).
    let payloads = payload_thread.join().unwrap_or_default();
    let domain_suffix: Option<String> = payloads
        .first()
        .and_then(|p| p.splitn(2, '.').nth(1).map(|s| s.to_string()));

    let stdout = child.stdout.take().expect("child stdout was piped");
    let reader = BufReader::new(stdout);

    for line in reader.lines() {
        let line = match line {
            Ok(l) => l,
            Err(_) => break,
        };
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        match serde_json::from_str::<Interaction>(line) {
            Ok(i) => print_interaction(&i, domain_suffix.as_deref()),
            Err(_) => { /* not a JSON interaction line; ignore */ }
        }
    }

    let _ = child.wait();
    let _ = fs::remove_file(&payload_file);
}

/// Print a single interaction in the minimal oob format.
fn print_interaction(i: &Interaction, domain_suffix: Option<&str>) {
    // Reconstruct the URL/host that was hit. full-id already contains the
    // unique id (possibly with a subdomain prefix); append the server domain.
    let host = match domain_suffix {
        Some(suffix) if !i.full_id.is_empty() => format!("{}.{}", i.full_id, suffix),
        _ if !i.full_id.is_empty() => i.full_id.clone(),
        _ => i.unique_id.clone(),
    };

    let proto = i.protocol.to_uppercase();
    let when = fmt_time(&i.timestamp);
    let stamp = colorize_timestamp(&when);

    let is_http = i.protocol.eq_ignore_ascii_case("http")
        || i.protocol.eq_ignore_ascii_case("https");

    // ANSI colours for the part after the timestamp.
    const RESET: &str = "\x1b[0m";
    const GREY: &str = "\x1b[38;2;150;150;150m"; // DNS lines
    const ORANGE: &str = "\x1b[38;2;255;165;0m"; // HTTP keyword

    // Header line: time, type (with DNS query type inline), generated URL.
    if !is_http {
        if let Some(qt) = i.q_type.as_deref().filter(|q| !q.is_empty()) {
            println!("{stamp} {GREY}{proto} ({qt}) {host}{RESET}");
            return;
        }
        // Non-HTTP, non-DNS (or DNS without a query type): grey the rest too.
        println!("{stamp} {GREY}{proto} {host}{RESET}");
        return;
    }
    println!("{stamp} {ORANGE}{proto}{RESET} {host}");

    // For HTTP/HTTPS interactions, show the full raw request (never response).
    if is_http {
        if let Some(req) = &i.raw_request {
            let normalized = req.replace("\r\n", "\n");
            let mut lines: Vec<&str> = normalized.lines().collect();
            while lines.last().map(|l| l.trim().is_empty()).unwrap_or(false) {
                lines.pop();
            }
            for rl in lines {
                println!("{rl}");
            }
        }
    }
}

fn print_help() {
    println!(
        "oob - minimal interactsh wrapper\n\n\
         Usage: oob [interactsh-client flags...]\n\n\
         Runs interactsh and shows only:\n\
         \x20 - the generated interactsh URL\n\
         \x20 - date/time of each interaction\n\
         \x20 - the interaction type (DNS, HTTP, ...)\n\
         \x20 - the full raw HTTP request for HTTP/HTTPS (never the response)\n\n\
         Any flags are passed through to interactsh (e.g. -n 3, -s oast.live)."
    );
}
