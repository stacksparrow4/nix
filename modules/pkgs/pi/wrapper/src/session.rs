use std::{env, process::Command};

use tempfile::{TempDir, tempdir};

use crate::{
    backend::{BRIDGE_DIR, Backend},
    local_net::{self, LocalNet},
    notes::NotesFs,
    notify,
    plan::{CwdMode, Plan, Target},
    settings::SettingsOverlay,
    volumes::{self, VolAccess, VolType, home_volume, pi_volume, volume},
};

const CONTROL_DIR: &str = "/tmp/pi-subagent";
const CONTROL_SOCKET: &str = "/tmp/pi-subagent/control.sock";

pub struct Session {
    backend: Backend,
    _notes: Option<NotesFs>,
    local_net: Option<LocalNet>,
    subagent_dir: Option<TempDir>,
    notify_dir: TempDir,
    settings: SettingsOverlay,
}

impl Session {
    pub fn start(plan: &Plan) -> Result<Session, String> {
        let subagent_dir = matches!(plan.target, Target::Sandbox)
            .then(|| tempdir().expect("Failed to create temporary subagent dir"));
        let local_net = plan.local.as_deref().map(LocalNet::start).transpose()?;
        let notes = plan.notes.as_deref().map(NotesFs::mount).transpose()?;
        let backend = Backend::start(
            plan,
            &sandbox_args(plan, subagent_dir.as_ref(), notes.as_ref()),
        )?;
        let notify_dir = notify::start_notify_server()?;
        let settings = SettingsOverlay::create();

        Ok(Session {
            backend,
            _notes: notes,
            local_net,
            subagent_dir,
            notify_dir,
            settings,
        })
    }

    pub fn launch(&self, plan: &Plan) -> Result<(), String> {
        let mut args = vec![];

        args.extend(pi_volume("auth.json", VolAccess::Rw, VolType::File));
        args.extend(volume(
            self.settings.path().display(),
            "~/.pi/agent/settings.json",
            VolAccess::Rw,
            VolType::File,
        ));
        args.extend(pi_volume("models-store.json", VolAccess::Rw, VolType::File));
        args.extend(pi_volume("models.json", VolAccess::Ro, VolType::File));
        args.extend(pi_volume("sessions", VolAccess::Rw, VolType::Dir));
        for (var, guest) in [
            ("SPRRW_EXTENSIONS", "~/.pi/agent/extensions"),
            ("SPRRW_PROMPTS", "~/.pi/agent/prompts"),
            ("SPRRW_THEMES", "~/.pi/agent/themes"),
        ] {
            args.extend(volume(
                env::var(var).unwrap(),
                guest,
                VolAccess::Ro,
                VolType::Dir,
            ));
        }

        args.push("--clipboard".to_string());

        if let Some(local_net) = &self.local_net {
            args.extend(local_net.box_args());
        }

        args.extend(volume(
            self.backend.bridge_dir().display(),
            BRIDGE_DIR,
            VolAccess::Ro,
            VolType::Dir,
        ));

        args.extend(notify::box_args(self.notify_dir.path()));

        if let Some(dir) = &self.subagent_dir {
            args.extend(volume(
                dir.path().display(),
                CONTROL_DIR,
                VolAccess::Rw,
                VolType::Dir,
            ));
            args.extend(volumes::env("PI_SUBAGENT_CONTROL", CONTROL_SOCKET));
        }

        if let Some(path) = &plan.agents_md {
            args.extend(volume(
                path.display(),
                "/AGENTS.md",
                VolAccess::Ro,
                VolType::File,
            ));
        }

        if !matches!(plan.target, Target::Remote(_)) {
            args.extend(volumes::env("PI_READ_AGENTS_MD", 1));
        }

        if plan.brave_search {
            args.extend(home_volume(
                ".config/brave-search",
                VolAccess::Ro,
                VolType::Dir,
            ));
        }

        let shell_prefix = if self.local_net.is_some() {
            local_net::SHELL_PREFIX
        } else {
            ""
        };
        let pi_cmd = pi_command(plan);
        let pi_cmd = shlex::try_join(pi_cmd.iter().map(String::as_str))
            .expect("Failed to create shell script for pi command");

        args.extend(["--downgrade-term", "--", "sh", "-c"].map(String::from));
        args.push(format!("{shell_prefix}{pi_cmd}"));

        Command::new("box")
            .args(args)
            .status()
            .map_err(|e| format!("Failed to launch sandboxed pi: {e}"))?;

        Ok(())
    }
}

fn sandbox_args(
    plan: &Plan,
    subagent_dir: Option<&TempDir>,
    notes: Option<&NotesFs>,
) -> Vec<String> {
    let mut args: Vec<String> = match plan.cwd {
        Some(CwdMode::Rw) => vec!["--cwd".to_string(), "--ro-git".to_string()],
        Some(CwdMode::Ro) => vec!["--ro-cwd".to_string()],
        None => vec![],
    };

    for v in &plan.volumes {
        args.extend(["-v".to_string(), v.clone()]);
    }

    if let Some(dir) = subagent_dir {
        args.extend(volume(
            dir.path().display(),
            CONTROL_DIR,
            VolAccess::Rw,
            VolType::Dir,
        ));
        args.extend(volumes::env("PI_SUBAGENT_SOCKET", CONTROL_SOCKET));
    }

    if let Some(notes) = notes {
        args.extend(volume(
            notes.path().display(),
            "/notes",
            VolAccess::Rw,
            VolType::Dir,
        ));
    }

    args.extend(plan.extra_sandbox_args.iter().cloned());
    args
}

fn pi_command(plan: &Plan) -> Vec<String> {
    let mut cmd: Vec<String> = vec![
        env::var("SPRRW_PI").unwrap(),
        "--approve".to_string(),
        "--no-tools".to_string(),
        "--no-extensions".to_string(),
    ];

    if !plan.tools.is_empty() {
        cmd.extend(["--tools".to_string(), plan.tools.join(",")]);
    }

    for e in &plan.extensions {
        cmd.extend(["-e".to_string(), format!("~/.pi/agent/extensions/{e}")]);
    }

    cmd.extend(["-e".to_string(), "builtin:llama.cpp".to_string()]);
    cmd.extend(["--system-prompt".to_string(), plan.system_prompt()]);

    if let Some(models) = &plan.models {
        cmd.extend(["--models".to_string(), models.clone()]);
    }

    cmd.extend(plan.pi_args.iter().cloned());
    cmd
}
