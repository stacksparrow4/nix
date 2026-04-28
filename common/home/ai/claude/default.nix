{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.sprrw.ai.claude.enable = lib.mkEnableOption "claude";

  config =
    let
      cfg = config.sprrw.ai.claude;
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
    in
    lib.mkIf cfg.enable {
      home.packages = [
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
      ];
    };
}
