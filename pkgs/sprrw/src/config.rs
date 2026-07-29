use std::collections::BTreeMap;
use std::path::PathBuf;

use serde::Deserialize;

pub const DEFAULT_FLAKE: &str = "/home/sprrw/nixos";

#[derive(Debug, Default, Deserialize)]
#[serde(default, rename_all = "kebab-case", deny_unknown_fields)]
pub struct FileConfig {
    #[serde(alias = "build_flake", alias = "buildFlake")]
    pub build_flake: Option<PathBuf>,

    #[serde(alias = "update_flake", alias = "updateFlake")]
    pub update_flake: Option<PathBuf>,

    #[serde(alias = "add_flakes", alias = "addFlakes")]
    pub add_flakes: Option<Vec<PathBuf>>,

    #[serde(alias = "override_inputs", alias = "overrideInputs")]
    pub override_inputs: Option<BTreeMap<String, String>>,
}

impl FileConfig {
    pub fn path() -> Option<PathBuf> {
        if let Some(dir) = std::env::var_os("XDG_CONFIG_HOME")
            && !dir.is_empty()
        {
            return Some(PathBuf::from(dir).join("sprrw.json"));
        }

        let home = std::env::var_os("HOME")?;
        Some(PathBuf::from(home).join(".config").join("sprrw.json"))
    }

    pub fn load() -> Result<Self, String> {
        let Some(path) = Self::path() else {
            return Ok(Self::default());
        };

        let contents = match std::fs::read_to_string(&path) {
            Ok(contents) => contents,
            Err(err) if err.kind() == std::io::ErrorKind::NotFound => {
                return Ok(Self::default());
            }
            Err(err) => return Err(format!("failed to read {}: {err}", path.display())),
        };

        serde_json::from_str(&contents)
            .map_err(|err| format!("failed to parse {}: {err}", path.display()))
    }
}

#[derive(Debug)]
pub struct Config {
    pub build_flake: PathBuf,
    pub update_flake: PathBuf,
    pub add_flakes: Vec<PathBuf>,
    pub override_inputs: BTreeMap<String, String>,
}

/// Parse a `NAME=VALUE` flake input override from the command line.
pub fn parse_override_input(raw: &str) -> Result<(String, String), String> {
    let (name, value) = raw
        .split_once('=')
        .ok_or_else(|| format!("invalid input override `{raw}`, expected NAME=VALUE"))?;

    if name.is_empty() {
        return Err(format!("invalid input override `{raw}`, input name is empty"));
    }

    if value.is_empty() {
        return Err(format!("invalid input override `{raw}`, value is empty"));
    }

    Ok((name.to_string(), value.to_string()))
}

impl Config {
    pub fn resolve(
        cli_build_flake: Option<PathBuf>,
        cli_update_flake: Option<PathBuf>,
        cli_add_flakes: Vec<PathBuf>,
        cli_override_inputs: Vec<(String, String)>,
        file: FileConfig,
    ) -> Result<Self, String> {
        // File overrides first, CLI ones win on conflict.
        let mut override_inputs = file.override_inputs.unwrap_or_default();
        override_inputs.extend(cli_override_inputs);

        let config = Self {
            override_inputs,
            build_flake: cli_build_flake
                .or(file.build_flake)
                .unwrap_or_else(|| PathBuf::from(DEFAULT_FLAKE)),
            update_flake: cli_update_flake
                .or(file.update_flake)
                .unwrap_or_else(|| PathBuf::from(DEFAULT_FLAKE)),
            add_flakes: if !cli_add_flakes.is_empty() {
                cli_add_flakes
            } else {
                file.add_flakes
                    .unwrap_or_else(|| vec![PathBuf::from(DEFAULT_FLAKE)])
            },
        };

        for path in std::iter::once(&config.build_flake)
            .chain(std::iter::once(&config.update_flake))
            .chain(config.add_flakes.iter())
        {
            if !path.is_absolute() {
                return Err(format!("{} is not an absolute path", path.display()));
            }
        }

        Ok(config)
    }
}
