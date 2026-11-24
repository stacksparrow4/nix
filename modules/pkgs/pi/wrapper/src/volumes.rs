use std::fmt::Display;

pub enum VolAccess {
    Ro,
    Rw,
}

pub enum VolType {
    File,
    Dir,
}

pub fn volume(
    host: impl Display,
    guest: impl Display,
    access: VolAccess,
    kind: VolType,
) -> [String; 2] {
    let access = match access {
        VolAccess::Ro => "ro",
        VolAccess::Rw => "rw",
    };
    let kind = match kind {
        VolType::File => "file",
        VolType::Dir => "dir",
    };
    ["-v".to_string(), format!("{host}:{guest}:{access}:{kind}")]
}

pub fn home_volume(rel: &str, access: VolAccess, kind: VolType) -> [String; 2] {
    let home = std::env::home_dir().expect("Could not find home directory");
    volume(home.join(rel).display(), format!("~/{rel}"), access, kind)
}

pub fn pi_volume(rel: &str, access: VolAccess, kind: VolType) -> [String; 2] {
    home_volume(&format!(".pi/agent/{rel}"), access, kind)
}

pub fn env(key: &str, value: impl Display) -> [String; 2] {
    ["--env".to_string(), format!("{key}={value}")]
}
