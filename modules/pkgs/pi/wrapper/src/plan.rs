use std::{
    env,
    path::{Path, PathBuf},
};

use crate::{
    Args,
    config::{self, PiConfig},
    remote::validate_remote_template,
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
    Remote(String),
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
    pub agents_md: Option<PathBuf>,
    pub volumes: Vec<String>,
    pub extra_sandbox_args: Vec<String>,
    pub print: bool,
    pub pi_args: Vec<String>,
}

impl Plan {
    pub fn from_args(args: Args) -> Result<Plan, String> {
        let target = resolve_target(args.remote, args.vm)?;

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

        let models = resolve_models(trim_list(args.models), pi_config.as_ref())?;

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
            agents_md,
            volumes: args.volume,
            extra_sandbox_args,
            print: args.print,
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

fn resolve_target(remote: Option<String>, vm: bool) -> Result<Target, String> {
    match remote {
        Some(template) => {
            validate_remote_template(&template)?;
            Ok(Target::Remote(template))
        }
        None if vm => Ok(Target::Vm),
        None => Ok(Target::Sandbox),
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
    requested: Vec<String>,
    pi_config: Option<&(PathBuf, PiConfig)>,
) -> Result<Option<String>, String> {
    let allowed = pi_config.and_then(|(path, config)| Some((path, config.models_list.as_ref()?)));

    match allowed {
        Some((_, allowed)) if requested.is_empty() => Ok(Some(allowed.join(","))),
        Some((path, allowed)) => {
            if let Some(model) = requested.iter().find(|&m| !allowed.contains(m)) {
                return Err(format!(
                    "Model '{}' is not in \"models-list\" of {}",
                    model,
                    path.display()
                ));
            }
            Ok(Some(requested.join(",")))
        }
        None if requested.is_empty() => Ok(None),
        None => Ok(Some(requested.join(","))),
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
