use std::{
    fmt::Display,
    fs,
    path::{Path, PathBuf},
};

use serde::Deserialize;

use crate::{models::ModelsList, notes::NotesName};

pub const CONFIG_FILE: &str = "pi-config.json";

#[derive(Deserialize, Default, Debug)]
#[serde(deny_unknown_fields, rename_all = "kebab-case")]
pub struct PiConfig {
    #[serde(default)]
    pub local_only: bool,
    #[serde(default)]
    pub allow_testing: bool,
    pub models_list: Option<ModelsList>,
    pub notes: Option<NotesName>,
    pub default_goal: Option<String>,
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

    Ok(Some((path, config)))
}
