{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.sprrw.ai = {
    enable = lib.mkEnableOption "ai";

    ollama.enable = lib.mkEnableOption "ollama";

    model = lib.mkOption {
      type = lib.types.str;
      default = "qwen3-coder:30b";
    };
  };

  config =
    let
      cfg = config.sprrw.ai;
      claudeSandboxArgs = {
        sharedPaths = [
          {
            hostPath = "$HOME/.local/claude-vm/.claude";
            boxPath = "/home/sprrw/.claude";
            ro = false;
            type = "dir";
          }
          {
            hostPath = "$HOME/.local/claude-vm/.claude.json";
            boxPath = "/home/sprrw/.claude.json";
            ro = false;
            type = "file";
          }
        ];
        downgradeTerm = true;
        stdin = true;
        tty = true;
        network = true;
        prog = "${pkgs.claude-code}/bin/claude --dangerously-skip-permissions";
      };
      qwenSandboxArgs = {
        sharedPaths = [
          {
            hostPath = "$HOME/.qwen";
            boxPath = "/home/sprrw/.qwen";
            ro = false;
            type = "dir";
          }
        ];
        envVars = [
          "OPENAI_API_KEY=ollama"
          "OPENAI_BASE_URL=\"$OLLAMA_HOST/v1\""
          "OPENAI_MODEL=\"${cfg.model}\""
        ];
        downgradeTerm = true;
        stdin = true;
        tty = true;
        network = true;
        prog = "${pkgs.qwen-code}/bin/qwen --yolo";
      };
    in
    lib.mkIf cfg.enable {
      services.ollama = lib.mkIf cfg.ollama.enable {
        enable = true;
        package = pkgs.ollama-cuda;
        environmentVariables = {
          OLLAMA_KEEP_ALIVE = "5m";
          # OLLAMA_CONTEXT_LENGTH = "64000";
        };
        host = "0.0.0.0"; # for docker. protected by firewall anyway
      };

      home.packages = with pkgs; [
        aichat

        (config.sprrw.sandbox.create (
          claudeSandboxArgs
          // {
            name = "claude-code-tmp";
          }
        ))

        (config.sprrw.sandbox.create (
          claudeSandboxArgs
          // {
            name = "claude-code";
            shareCwd = true;
          }
        ))
        (config.sprrw.sandbox.create (
          claudeSandboxArgs
          // {
            # TODO: version match with the VM instead of assuming path same as host
            name = "claude-code-vm";
            type = "vm";
            sharedPaths = [
              {
                hostPath = "$HOME/.local/claude-vm";
                boxPath = "/mnt/claude";
                ro = false;
                type = "dir";
              }
            ];
            shareCwd = true;
            insideBeforeScript = ''
              ln -s /mnt/claude/.claude ~/.claude
              ln -s /mnt/claude/.claude.json ~/.claude.json
              export TERM=xterm-256color
              export COLORTERM=truecolor
            '';
          }
        ))

        (config.sprrw.sandbox.create (
          qwenSandboxArgs
          // {
            name = "qwen-code-tmp";
          }
        ))
        (config.sprrw.sandbox.create (
          qwenSandboxArgs
          // {
            name = "qwen-code";
            shareCwd = true;
          }
        ))
      ];
    };
}
