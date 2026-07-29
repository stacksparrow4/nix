use std::path::{Path, PathBuf};

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum Kind {
    Dir,
    File,
    Unknown,
}

#[derive(Clone)]
pub struct Mount {
    pub host_path: PathBuf,
    pub box_path: String,
    pub kind: Kind,
    pub read_only: bool,
}

impl Mount {
    pub fn new(host_path: impl Into<PathBuf>, box_path: impl Into<String>, kind: Kind) -> Self {
        Self {
            host_path: host_path.into(),
            box_path: box_path.into(),
            kind,
            read_only: false,
        }
    }

    pub fn read_only(mut self) -> Self {
        self.read_only = true;
        self
    }

    pub fn to_bwrap_args(&self) -> [String; 3] {
        [
            if self.read_only {
                "--ro-bind"
            } else {
                "--bind"
            }
            .to_string(),
            self.host_path.display().to_string(),
            self.box_path.clone(),
        ]
    }

    /// Create the host side if it is missing, which requires knowing what to make.
    pub fn ensure_exists(&self) -> Result<(), String> {
        if self.host_path.exists() {
            return Ok(());
        }
        match self.kind {
            Kind::Dir => std::fs::create_dir_all(&self.host_path)
                .map_err(|e| format!("could not create {}: {e}", self.host_path.display())),
            Kind::File => {
                if let Some(parent) = self.host_path.parent() {
                    let _ = std::fs::create_dir_all(parent);
                }
                std::fs::File::create(&self.host_path)
                    .map(|_| ())
                    .map_err(|e| format!("could not create {}: {e}", self.host_path.display()))
            }
            Kind::Unknown => Err(format!(
                "the mount {} did not exist on the host and no type was specified to autocreate with",
                self.host_path.display()
            )),
        }
    }
}

/// Parse a `hostpath:boxpath:ro/rw:type` volume specification.
pub fn parse_volume(spec: &str) -> Result<Mount, String> {
    let parts: Vec<&str> = spec.split(':').collect();
    if parts.len() < 2 {
        return Err(format!("the mount {spec} needs at least hostpath:boxpath"));
    }

    let read_only = match parts.get(2) {
        None | Some(&"") | Some(&"rw") => false,
        Some(&"ro") => true,
        Some(other) => return Err(format!("the mount {spec} has invalid type {other}")),
    };

    let kind = match parts.get(3) {
        Some(&"dir") => Kind::Dir,
        Some(&"file") => Kind::File,
        None | Some(&"") => Kind::Unknown,
        Some(other) => return Err(format!("invalid type for {spec}: {other}")),
    };

    let mut mount = Mount::new(parts[0], parts[1], kind);
    mount.read_only = read_only;
    Ok(mount)
}

/// Every symlink under `root`, which is how home-manager's generated home files
/// are discovered so they can be mapped into the box individually.
pub fn find_symlinks(root: &Path) -> Vec<PathBuf> {
    let mut found = Vec::new();
    let mut stack = vec![root.to_path_buf()];

    while let Some(dir) = stack.pop() {
        let Ok(entries) = std::fs::read_dir(&dir) else {
            continue;
        };
        for entry in entries.flatten() {
            let path = entry.path();
            // symlink_metadata, so that symlinks are reported rather than followed.
            let Ok(meta) = path.symlink_metadata() else {
                continue;
            };
            if meta.file_type().is_symlink() {
                found.push(path);
            } else if meta.is_dir() {
                stack.push(path);
            }
        }
    }

    found.sort();
    found
}
