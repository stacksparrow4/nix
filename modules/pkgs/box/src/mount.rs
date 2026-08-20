pub const BOX_CWD: &str = "/home/sprrw/box";
pub const BOX_HOME: &str = "/home/sprrw";

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum MountType {
    Unknown,
    Dir,
    File,
}

impl MountType {
    pub fn parse(value: &str) -> Option<Self> {
        match value {
            "unknown" => Some(Self::Unknown),
            "dir" => Some(Self::Dir),
            "file" => Some(Self::File),
            _ => None,
        }
    }
}

#[derive(Clone, Debug)]
pub struct Mount {
    pub host_path: String,
    pub box_path: String,
    pub mount_type: MountType,
    pub ro: bool,
    _private: (),
}

impl Mount {
    pub fn new(host_path: &str, box_path: &str, mount_type: MountType, ro: bool) -> Self {
        Self {
            host_path: host_path.to_string(),
            box_path: match box_path.strip_prefix("~/") {
                Some(rest) => format!("{}/{}", BOX_HOME, rest),
                None => box_path.to_string(),
            },
            mount_type,
            ro,
            _private: (),
        }
    }

    pub fn to_bwrap_args(&self) -> [String; 3] {
        [
            if self.ro { "--ro-bind" } else { "--bind" }.to_string(),
            self.host_path.clone(),
            self.box_path.clone(),
        ]
    }

    pub fn to_docker_args(&self) -> [String; 2] {
        [
            "-v".to_string(),
            format!(
                "{}:{}:{}",
                self.host_path,
                self.box_path,
                if self.ro { "ro" } else { "rw" }
            ),
        ]
    }
}

pub fn build_stage_script(mounts: &[Mount], stage: &str, ro_git: bool) -> Vec<String> {
    let mut lines = vec![
        "set -e".to_string(),
        format!("mount -t tmpfs tmpfs {}", quote(stage)),
    ];

    for (i, m) in mounts.iter().enumerate() {
        let root = format!("{stage}/{i}");
        lines.push(format!("mkdir -p {}", quote(&root)));
        lines.push(format!(
            "mount --bind {} {}",
            quote(&m.host_path),
            quote(&root)
        ));

        if ro_git && m.box_path == BOX_CWD {
            let git = format!("{root}/.git");
            lines.push(format!("mount --bind {} {}", quote(&git), quote(&git)));
            lines.push(format!("mount -o remount,bind,ro {}", quote(&git)));
        }

        if m.ro {
            lines.push(format!("mount -o remount,bind,ro {}", quote(&root)));
        }
    }

    lines
}

pub fn quote(value: &str) -> String {
    shlex::try_quote(value)
        .expect("cannot quote a value containing a nul byte")
        .into_owned()
}
