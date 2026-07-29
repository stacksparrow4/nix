//! Serve the bridge with the ssh executor, for testing the remote command
//! construction (base64 payload, cd, timeout wrapper) without needing a real VM.
//!
//! Usage: serve_ssh <socket> <cwd> <ssh-program>

use std::path::Path;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let socket = &args[1];
    let cwd = args[2].clone();
    let ssh = args[3].clone();

    bridge::serve(
        Path::new(socket),
        bridge::Ssh {
            base: vec![ssh],
            cwd,
            grace: 5,
        },
    )
    .expect("serve failed");
}
