use std::collections::{BTreeMap, BTreeSet};
use std::io::{self, ErrorKind};
use std::path::PathBuf;

use serde::Deserialize;
use thiserror::Error;

#[derive(Debug, Default, Deserialize)]
#[serde(default, rename_all = "kebab-case", deny_unknown_fields)]
pub struct FileConfig {
    pub build_flake: Option<PathBuf>,
    pub update_flakes: Option<Vec<PathBuf>>,
    pub override_inputs: Option<BTreeMap<String, String>>,
}

#[derive(Error, Debug)]
pub enum ConfigLoadError {
    #[error("failed to read config file: {0}")]
    FailedRead(#[from] io::Error),

    #[error("failed to parse config file: {0}")]
    FailedParse(#[from] serde_json::Error),
}

impl FileConfig {
    pub fn load() -> Result<Self, ConfigLoadError> {
        let path = PathBuf::from(std::env::var_os("HOME").expect("HOME env var not set"))
            .join(".config")
            .join("sprrw.json");

        match std::fs::read_to_string(&path) {
            Ok(contents) => serde_json::from_str(&contents).map_err(ConfigLoadError::FailedParse),
            Err(e) => match e.kind() {
                ErrorKind::NotFound => Ok(Self::default()),
                _ => Err(ConfigLoadError::FailedRead(e)),
            },
        }
    }
}

#[derive(Debug)]
pub struct Config {
    pub build_flake: PathBuf,
    pub update_flakes: Vec<PathBuf>,
    pub add_flakes: BTreeSet<PathBuf>,
    pub override_inputs: BTreeMap<String, String>,
}

fn get_flake_uri_path(value: &str) -> Option<PathBuf> {
    Some(PathBuf::from(
        value
            .strip_prefix("git+file://")?
            .split(['?', '#'])
            .next()
            .unwrap(),
    ))
}

impl Config {
    pub fn load(
        cli_build_flake: Option<PathBuf>,
        cli_update_flakes: Vec<PathBuf>,
        cli_override_inputs: Vec<(String, String)>,
    ) -> Result<Self, ConfigLoadError> {
        let file = FileConfig::load()?;

        let mut override_inputs = file.override_inputs.unwrap_or_default();
        override_inputs.extend(cli_override_inputs);

        let default_flake =
            PathBuf::from(std::env::var_os("HOME").expect("HOME env var not set")).join("nixos");

        let build_flake = cli_build_flake
            .or(file.build_flake)
            .unwrap_or_else(|| default_flake.clone());

        let update_flakes = if !cli_update_flakes.is_empty() {
            cli_update_flakes
        } else {
            file.update_flakes.unwrap_or_else(|| vec![default_flake])
        };

        let add_flakes: BTreeSet<PathBuf> = std::iter::once(build_flake.clone())
            .chain(update_flakes.iter().cloned())
            .chain(
                override_inputs
                    .values()
                    .filter_map(|value| get_flake_uri_path(value)),
            )
            .collect();

        Ok(Self {
            override_inputs,
            build_flake,
            update_flakes,
            add_flakes,
        })
    }
}
