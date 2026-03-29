{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.sprrw.ai = {
    enable = lib.mkEnableOption "ai";
  };

  config =
    let
      cfg = config.sprrw.ai;
    in
    lib.mkIf cfg.enable {
      services.ollama = {
        enable = true;
        package = pkgs.ollama-cuda;
        environmentVariables = {
          OLLAMA_KEEP_ALIVE = "5m";
          OLLAMA_CONTEXT_LENGTH = "16000";
        };
        host = "0.0.0.0"; # for docker. protected by firewall anyway
      };

      home.packages = with pkgs; [
        aichat
        (pkgs.writeShellApplication {
          name = "claude-box";
          text = ''
            mkdir -p ~/.claude
            touch ~/.claude.json

            TERM=xterm-256color ${config.sprrw.sandboxing.runDocker} \
              -it \
              -v ~/.claude:/home/sprrw/.claude -v ~/.claude.json:/home/sprrw/.claude.json \
              DOCKERIMG \
              ${pkgs.claude-code}/bin/claude --dangerously-skip-permissions "$@"
          '';
        })
        (pkgs.writeShellApplication {
          name = "claude-code-box";
          text = ''
            mkdir -p ~/.claude
            touch ~/.claude.json

            TERM=xterm-256color ${config.sprrw.sandboxing.runDocker} \
              ${config.sprrw.sandboxing.recipes.pwd_starter} \
              -v ~/.claude:/home/sprrw/.claude -v ~/.claude.json:/home/sprrw/.claude.json \
              DOCKERIMG \
              ${pkgs.claude-code}/bin/claude --dangerously-skip-permissions "$@"
          '';
        })
        (pkgs.writeShellApplication {
          name = "claude";
          text = ''
            mkdir -p ~/.local/claude-vm/.claude
            touch ~/.local/claude-vm/.claude.json

            ${
              config.sprrw.sandboxing.runVM {
                qemu_args = "-virtfs local,path=$HOME/.local/claude-vm,mount_tag=claudeshare,security_model=none,id=host0";
                script = ''
                  sudo mkdir -p /mnt/claude
                  sudo mount -t 9p -o trans=virtio,version=9p2000.L claudeshare /mnt/claude
                  ln -s /mnt/claude/.claude ~/.claude
                  ln -s /mnt/claude/.claude.json ~/.claude.json
                  TERM=xterm-256color ${pkgs.claude-code}/bin/claude --dangerously-skip-permissions "$@"
                '';
              }
            } "$@"
          '';
        })
        (pkgs.writeShellApplication {
          name = "claude-code";
          text = ''
            mkdir -p ~/.local/claude-vm/.claude
            touch ~/.local/claude-vm/.claude.json

            ${
              config.sprrw.sandboxing.runVM {
                qemu_args = "-virtfs local,path=$HOME/.local/claude-vm,mount_tag=claudeshare,security_model=none,id=host0 -virtfs local,path=$(pwd),mount_tag=pwdshare,security_model=none,id=host1";
                script = ''
                  sudo mkdir -p /mnt/claude
                  sudo mount -t 9p -o trans=virtio,version=9p2000.L claudeshare /mnt/claude
                  ln -s /mnt/claude/.claude ~/.claude
                  ln -s /mnt/claude/.claude.json ~/.claude.json
                  sudo mkdir -p /mnt/pwd
                  sudo mount -t 9p -o trans=virtio,version=9p2000.L pwdshare /mnt/pwd
                  cd /mnt/pwd
                  TERM=xterm-256color ${pkgs.claude-code}/bin/claude --dangerously-skip-permissions "$@"
                '';
              }
            } "$@"
          '';
        })
      ];
    };
}
