use std::env;
use std::path::{Path, PathBuf};
use std::process::{Command, exit};

fn main() {
    let nvim = env::var("SPRRW_NVIM").expect("SPRRW_NVIM is not set");

    if env::var("IN_SPRRW_SANDBOX").as_deref() == Ok("1") {
        let args: Vec<String> = env::args().skip(1).collect();
        let status = Command::new(&nvim)
            .args(&args)
            .status()
            .expect("failed to run neovim");
        exit(status.code().unwrap_or(1));
    }

    let raw_args: Vec<String> = env::args().skip(1).collect();
    let (share_dir, vim_args) = compute_share(raw_args);

    let status = Command::new("box")
        .current_dir(&share_dir)
        .arg("--cwd")
        .arg("--clipboard")
        .arg("--ro-git")
        .arg("--")
        .arg(&nvim)
        .args(&vim_args)
        .status()
        .expect("failed to launch box");

    exit(status.code().unwrap_or(1));
}

fn compute_share(args: Vec<String>) -> (PathBuf, Vec<String>) {
    let cwd = env::current_dir().expect("failed to get current working directory");

    if args.len() == 1 && args[0].starts_with('/') {
        let path = Path::new(&args[0]);
        if path.is_dir() {
            return (path.to_path_buf(), vec![".".to_string()]);
        }
        let dir = path
            .parent()
            .filter(|p| !p.as_os_str().is_empty())
            .map(Path::to_path_buf)
            .unwrap_or(cwd);
        let file = path
            .file_name()
            .map(|f| f.to_string_lossy().into_owned())
            .unwrap_or_else(|| args[0].clone());
        return (dir, vec![file]);
    }

    (cwd, args)
}
