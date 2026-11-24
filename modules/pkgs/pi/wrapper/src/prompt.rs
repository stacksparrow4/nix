use crate::{
    notes::{DIR_MAX_ENTRIES, NAME_MAX_BYTES, NOTE_MAX_BYTES},
    plan::{CwdMode, Plan, Target},
};

impl Plan {
    pub fn system_prompt(&self) -> String {
        if let Some(system) = &self.custom_system {
            return system.clone();
        }

        if self.bare {
            return String::from("You are a technical assistant.");
        }

        let date = format!(
            "Current date: {}",
            chrono::Local::now().format("%A, %B %-d, %Y")
        );

        if self.search {
            return format!(
                "You are a technical research assistant that searches the web to \
                provide information.\n\n{date}"
            );
        }

        let guidelines = self
            .guidelines()
            .into_iter()
            .map(String::from)
            .chain(self.notes_guideline())
            .map(|g| format!("- {g}"))
            .collect::<Vec<String>>()
            .join("\n");

        format!(
            "You are a pragmatic, task-oriented terminal agent. You focus solely on completing \
            the user's requests.\n\nGuidelines:\n{guidelines}\n\n{date}"
        )
    }

    fn notes_guideline(&self) -> Option<String> {
        self.notes.is_some().then(|| {
            format!(
                "Persistent notes are stored in the directory /notes. Search notes before \
                starting a task. Maintain up to date notes, this means adding, editing, deleting \
                and refactoring/reorganising notes to ensure they are neat. To avoid flooding \
                agent context, notes have limits: files ≤{NOTE_MAX_BYTES} bytes, names \
                ≤{NAME_MAX_BYTES} bytes, ≤{DIR_MAX_ENTRIES} entries per directory."
            )
        })
    }

    fn guidelines(&self) -> Vec<&'static str> {
        let mut guidelines = vec![];

        if self.has_tool("bash") && matches!(self.target, Target::Sandbox) && self.local.is_none()
        {
            guidelines.push(
                "Avoid recalling information about source available software and \
                instead answer definitively by cloning the source to /tmp and referring to it",
            );
            guidelines.push("`uv` is available for Python packages");
            guidelines.push(
                "You are in an Alpine container with a read-only /nix volume \
                mounted in. Use apk to install packages.",
            );
            guidelines.push("Never use `find` on the root directory for performance reasons.");
        }

        if self.local.is_some() {
            guidelines.push("You are in a sandbox with no network access.");
        }

        if self.brave_search {
            guidelines.push("Perform web searches when you are unsure of current information");
        }

        if self.cwd.is_some() {
            guidelines.push(
                "The user has mounted data into the sandbox at the current working \
                directory. The user's question will be in reference to the data in the current \
                working directory.",
            );
        }

        if self.cwd == Some(CwdMode::Rw) {
            guidelines.push("When writing code, never use comments unless explicitly asked.");
            if !self.allow_testing {
                guidelines.push("Never test the code you wrote unless explicitly asked.");
            }
        }

        guidelines.push(
            "When asking the user a question, only ask one question at a time. \
            This means that your next questions can use the context from the previous answer.",
        );

        guidelines
    }
}
