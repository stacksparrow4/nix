{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.sprrw.ai = {
    enable = lib.mkEnableOption "ai";

    model = lib.mkOption {
      type = lib.types.str;
      default = "qwen3-coder:30b";
    };
  };

  config =
    let
      cfg = config.sprrw.ai;
      createOllamaBridge = ''
        if ! docker network inspect ollama-network &>/dev/null; then
          docker network create --driver bridge --opt com.docker.network.bridge.name=br-ollama ollama-network
        fi
      '';
    in
    lib.mkIf cfg.enable {
      services.ollama = {
        enable = true;
        package = pkgs.ollama-cuda;
        environmentVariables = {
          OLLAMA_KEEP_ALIVE = "5m";
          OLLAMA_CONTEXT_LENGTH = "64000";
        };
        host = "0.0.0.0"; # for docker. protected by firewall anyway
      };

      home.packages = with pkgs; [
        aichat

        (pkgs.writeShellApplication {
          name = "claude-code";
          text = ''
            mkdir -p ~/.local/claude-vm/.claude
            touch ~/.local/claude-vm/.claude.json

            TERM=xterm-256color ${config.sprrw.sandboxing.runDocker} \
              ${config.sprrw.sandboxing.recipes.pwd_starter} \
              -v ~/.local/claude-vm/.claude:/home/sprrw/.claude -v ~/.local/claude-vm/.claude.json:/home/sprrw/.claude.json \
              DOCKERIMG \
              ${pkgs.claude-code}/bin/claude --dangerously-skip-permissions "$@"
          '';
        })
        (pkgs.writeShellApplication {
          name = "claude-code-vm";
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
        (pkgs.writeShellApplication {
          name = "qwen-code";
          text = ''
            mkdir -p ~/.qwen

            ${createOllamaBridge}

            OLLAMA_HOST="''${OLLAMA_HOST:-http://host.docker.internal:11434}"

            TERM=xterm-256color ${config.sprrw.sandboxing.runDocker} \
              ${config.sprrw.sandboxing.recipes.pwd_starter} \
              -v ~/.qwen:/home/sprrw/.qwen \
              --network ollama-network \
              --add-host host.docker.internal="$(docker network inspect ollama-network --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}')" \
              -e OPENAI_API_KEY=ollama \
              -e OPENAI_BASE_URL="$OLLAMA_HOST/v1" \
              -e OPENAI_MODEL=${cfg.model} \
              DOCKERIMG \
              ${pkgs.qwen-code}/bin/qwen --yolo "$@"
          '';
        })
      ];
    };
}
