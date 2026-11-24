use std::path::{Path, PathBuf};

use serde::Deserialize;

pub const CONFIG_FILE: &str = ".pi-config.json";

#[derive(Deserialize, Default, Debug)]
#[serde(deny_unknown_fields, rename_all = "kebab-case")]
pub struct PiConfig {
    #[serde(default)]
    pub local_only: bool,
    pub models_list: Option<Vec<String>>,
}

fn fail(path: &Path, msg: impl std::fmt::Display) -> ! {
    eprintln!("Invalid {}: {}", path.display(), msg);
    std::process::exit(2);
}

pub fn find_config(cwd: &Path) -> Option<(PathBuf, PiConfig)> {
    for dir in cwd.ancestors() {
        let path = dir.join(CONFIG_FILE);
        if !path.exists() {
            continue;
        }

        let contents = std::fs::read_to_string(&path).unwrap_or_else(|e| fail(&path, e));
        let config: PiConfig = serde_json::from_str(&contents).unwrap_or_else(|e| fail(&path, e));

        if let Some(models) = &config.models_list {
            if models.is_empty() {
                fail(&path, "\"models-list\" must not be empty");
            }
            if models.iter().any(|m| m.trim().is_empty() || m.contains(',')) {
                fail(
                    &path,
                    "\"models-list\" entries must be non-empty and must not contain ','",
                );
            }
        }

        return Some((path, config));
    }

    None
}
