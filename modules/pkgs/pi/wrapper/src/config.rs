use std::{
    fmt::Display,
    fs,
    path::{Path, PathBuf},
};

use serde::Deserialize;

pub const CONFIG_FILE: &str = ".pi-config.json";

#[derive(Deserialize, Default, Debug)]
#[serde(deny_unknown_fields, rename_all = "kebab-case")]
pub struct PiConfig {
    #[serde(default)]
    pub local_only: bool,
    pub models_list: Option<Vec<String>>,
}

impl PiConfig {
    fn validate(&self) -> Result<(), &'static str> {
        let Some(models) = &self.models_list else {
            return Ok(());
        };
        if models.is_empty() {
            return Err("\"models-list\" must not be empty");
        }
        if models.iter().any(|m| m.trim().is_empty() || m.contains(',')) {
            return Err("\"models-list\" entries must be non-empty and must not contain ','");
        }
        Ok(())
    }
}

fn invalid(path: &Path, msg: impl Display) -> String {
    format!("Invalid {}: {}", path.display(), msg)
}

pub fn find_config(cwd: &Path) -> Result<Option<(PathBuf, PiConfig)>, String> {
    let Some(path) = cwd
        .ancestors()
        .map(|dir| dir.join(CONFIG_FILE))
        .find(|path| path.exists())
    else {
        return Ok(None);
    };

    let contents = fs::read_to_string(&path).map_err(|e| invalid(&path, e))?;
    let config: PiConfig = serde_json::from_str(&contents).map_err(|e| invalid(&path, e))?;
    config.validate().map_err(|e| invalid(&path, e))?;

    Ok(Some((path, config)))
}
