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
}

impl Config {
    pub fn resolve(
        cli_build_flake: Option<PathBuf>,
        cli_update_flake: Option<PathBuf>,
        cli_add_flakes: Vec<PathBuf>,
        file: FileConfig,
    ) -> Result<Self, String> {
        let config = Self {
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
