use std::{env, fs, path::PathBuf};

use serde_json::{Value, json};
use tempfile::{TempDir, tempdir};

const SETTINGS_STRIP_KEYS: &[&str] = &["packages", "extensions", "skills", "prompts", "themes"];
const SETTINGS_FILE: &str = "settings.json";

pub struct SettingsOverlay {
    dir: TempDir,
}

impl SettingsOverlay {
    pub fn create() -> SettingsOverlay {
        let user_path = env::home_dir()
            .expect("Could not find home directory")
            .join(".pi/agent")
            .join(SETTINGS_FILE);

        let mut settings = fs::read_to_string(&user_path)
            .ok()
            .and_then(|s| serde_json::from_str::<Value>(&s).ok())
            .and_then(|v| match v {
                Value::Object(map) => Some(map),
                _ => None,
            })
            .unwrap_or_default();

        for key in SETTINGS_STRIP_KEYS {
            settings.remove(*key);
        }

        let Value::Object(overrides) = json!({
            "lastChangelogVersion": env::var("SPRRW_PI_VERSION").unwrap(),
            "cacheWarming": "idle",
            "showCacheMissNotices": true,
            "enableInstallTelemetry": false,
            "theme": "moonfly",
            "tuiMode": "regular",
            "warnings": {"anthropicExtraUsage": false},
        }) else {
            unreachable!()
        };
        settings.extend(overrides);

        let dir = tempdir().expect("Failed to create temporary settings dir");
        fs::write(
            dir.path().join(SETTINGS_FILE),
            serde_json::to_string_pretty(&settings).expect("Failed to serialize settings overlay"),
        )
        .expect("Failed to write settings overlay");

        SettingsOverlay { dir }
    }

    pub fn path(&self) -> PathBuf {
        self.dir.path().join(SETTINGS_FILE)
    }
}
