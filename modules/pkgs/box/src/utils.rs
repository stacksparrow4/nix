use std::os::unix::process::ExitStatusExt;
use std::process::ExitStatus;

pub fn exit_code(status: &ExitStatus) -> i32 {
    match status.code() {
        Some(code) => code,
        None => -status.signal().unwrap_or(1),
    }
}
