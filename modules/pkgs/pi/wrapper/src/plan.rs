use std::{
    env,
    path::{Path, PathBuf},
};

use crate::{
    Args,
    config::{self, PiConfig},
    models::{self, ModelName},
    notes::NotesName,
    remote::RemoteTemplate,
};

const DEFAULT_EXTENSIONS: &[&str] = &[
    "ask-mode.ts",
    "goal.ts",
    "brave-search.ts",
    "footer.ts",
    "notify.ts",
    "subagent.ts",
    "cache-warming.ts",
    "openrouter.ts",
    "vi-mode.ts",
    "btw.ts",
];
const REQUIRED_EXTENSIONS: &[&str] = &["pi-remote.ts"];
const DEFAULT_TOOLS: &[&str] = &["read", "write", "edit", "bash", "complete_goal"];

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum CwdMode {
    Rw,
    Ro,
}

pub enum Target {
    Sandbox,
    Vm,
    Remote(RemoteTemplate),
}

pub struct Plan {
    pub target: Target,
    pub cwd: Option<CwdMode>,
    pub local: Option<String>,
    pub brave_search: bool,
    pub tools: Vec<String>,
    pub extensions: Vec<String>,
    pub models: Option<String>,
    pub custom_system: Option<String>,
    pub bare: bool,
    pub search: bool,
    pub allow_testing: bool,
    pub agents_md: Option<PathBuf>,
    pub notes: Option<PathBuf>,
    pub default_goal: Option<String>,
    pub volumes: Vec<String>,
    pub extra_sandbox_args: Vec<String>,
    pub pi_args: Vec<String>,
}

impl Plan {
    pub fn from_args(args: Args) -> Result<Plan, String> {
        let target = resolve_target(args.remote, args.vm);

        let cwd = if args.cwd {
            Some(CwdMode::Rw)
        } else if args.ro_cwd {
            Some(CwdMode::Ro)
        } else {
            None
        };

        let agents_md = if args.agents {
            Some(resolve_agents_md()?)
        } else {
            None
        };

        let pi_config = match cwd {
            Some(_) => config::find_config(&current_dir())?,
            None => None,
        };

        if let Some((path, config)) = &pi_config {
            check_local_only(path, config, &target, args.local.is_some())?;
        }

        let notes = resolve_notes_name(args.notes, pi_config.as_ref())?
            .map(|name| resolve_notes(&name, &target))
            .transpose()?;

        let models = resolve_models(args.models, pi_config.as_ref())?;

        let default_goal = pi_config
            .as_ref()
            .and_then(|(_, c)| c.default_goal.clone())
            .map(|g| g.trim().to_string())
            .filter(|g| !g.is_empty());

        let brave_search = !(args.no_brave_search || args.local.is_some());

        let tools = resolve_tools(
            trim_list(args.tools),
            args.bare,
            !(args.no_tools || args.search),
            brave_search,
        );

        let extensions = resolve_extensions(trim_list(args.extensions), !args.no_extensions);

        let extra_sandbox_args = match args.additional_sandbox_args {
            Some(a) => shlex::split(&a)
                .ok_or_else(|| "Invalid value for --additional-sandbox-args".to_string())?,
            None => vec![],
        };

        Ok(Plan {
            target,
            cwd,
            local: args.local,
            brave_search,
            tools,
            extensions,
            models,
            custom_system: args.system,
            bare: args.bare,
            search: args.search,
            allow_testing: args.allow_testing
                || pi_config.as_ref().is_some_and(|(_, c)| c.allow_testing),
            agents_md,
            notes,
            default_goal,
            volumes: args.volume,
            extra_sandbox_args,
            pi_args: args.args,
        })
    }

    pub fn has_tool(&self, name: &str) -> bool {
        self.tools.iter().any(|t| t == name)
    }
}

fn current_dir() -> PathBuf {
    env::current_dir().expect("Failed to get the current working directory")
}

fn trim_list(items: Vec<String>) -> Vec<String> {
    items
        .into_iter()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .collect()
}

fn resolve_target(remote: Option<RemoteTemplate>, vm: bool) -> Target {
    match remote {
        Some(template) => Target::Remote(template),
        None if vm => Target::Vm,
        None => Target::Sandbox,
    }
}

fn resolve_agents_md() -> Result<PathBuf, String> {
    let path = current_dir().join("AGENTS.md");
    if !path.is_file() {
        return Err(format!(
            "--agents was supplied but {} does not exist",
            path.display()
        ));
    }
    Ok(path)
}

fn resolve_notes_name(
    requested: Option<NotesName>,
    pi_config: Option<&(PathBuf, PiConfig)>,
) -> Result<Option<NotesName>, String> {
    let fixed = pi_config.and_then(|(path, config)| Some((path, config.notes.as_ref()?)));

    match (fixed, requested) {
        (Some((path, fixed)), Some(requested)) if *fixed != requested => Err(format!(
            "Notes '{}' conflicts with \"notes\" '{}' in {}",
            requested,
            fixed,
            path.display()
        )),
        (Some((_, fixed)), _) => Ok(Some(fixed.clone())),
        (None, requested) => Ok(requested),
    }
}

fn resolve_notes(name: &NotesName, target: &Target) -> Result<PathBuf, String> {
    if !matches!(target, Target::Sandbox) {
        return Err("--notes is not supported with --vm or --remote".to_string());
    }
    let dir = env::home_dir()
        .expect("Could not find home directory")
        .join(".pi/notes")
        .join(name.as_str());
    std::fs::create_dir_all(&dir)
        .map_err(|e| format!("Failed to create notes dir {}: {e}", dir.display()))?;
    Ok(dir)
}

fn check_local_only(
    path: &Path,
    config: &PiConfig,
    target: &Target,
    local: bool,
) -> Result<(), String> {
    if !config.local_only {
        return Ok(());
    }
    if !local {
        return Err(format!("{} requires --local", path.display()));
    }
    if !matches!(target, Target::Sandbox) {
        return Err(format!(
            "{} is local-only and cannot be used with --vm or --remote",
            path.display()
        ));
    }
    Ok(())
}

fn resolve_models(
    requested: Vec<ModelName>,
    pi_config: Option<&(PathBuf, PiConfig)>,
) -> Result<Option<String>, String> {
    let allowed = pi_config.and_then(|(path, config)| Some((path, config.models_list.as_ref()?)));

    match allowed {
        Some((_, allowed)) if requested.is_empty() => Ok(Some(models::join(allowed))),
        Some((path, allowed)) => {
            if let Some(model) = requested.iter().find(|&m| !allowed.contains(m)) {
                return Err(format!(
                    "Model '{}' is not in \"models-list\" of {}",
                    model,
                    path.display()
                ));
            }
            Ok(Some(models::join(&requested)))
        }
        None if requested.is_empty() => Ok(None),
        None => Ok(Some(models::join(&requested))),
    }
}

fn resolve_tools(
    requested: Vec<String>,
    bare: bool,
    defaults: bool,
    brave_search: bool,
) -> Vec<String> {
    if bare {
        return vec![];
    }

    let mut tools = requested;
    if defaults {
        tools.extend(DEFAULT_TOOLS.iter().map(|t| t.to_string()));
    }
    if brave_search {
        tools.push("web_search".to_string());
    }
    tools
}

fn resolve_extensions(requested: Vec<String>, defaults: bool) -> Vec<String> {
    let mut extensions = requested;
    if defaults {
        extensions.extend(DEFAULT_EXTENSIONS.iter().map(|e| e.to_string()));
    }
    extensions.extend(REQUIRED_EXTENSIONS.iter().map(|e| e.to_string()));
    extensions
}
