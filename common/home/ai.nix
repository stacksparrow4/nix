{ pkgs, lib, config, ... }:

{
  options.sprrw.ai = {
    enable = lib.mkEnableOption "ai";

    model = lib.mkOption {
      type = lib.types.str;
      default = "qwen3-coder:30b";
    };
  };

  config = let
    cfg = config.sprrw.ai;
    createOllamaBridge = ''
      if ! docker network inspect ollama-network &>/dev/null; then
        docker network create --driver bridge --opt com.docker.network.bridge.name=br-ollama ollama-network
      fi
    '';
  in lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      aichat
      (pkgs.writeShellApplication {
        name = "claude-code";
        text = ''
          mkdir -p ~/.claude
          touch ~/.claude.json

          ${config.sprrw.sandboxing.runDocker} \
            ${config.sprrw.sandboxing.recipes.pwd_starter} \
            -v ~/.claude:/home/sprrw/.claude -v ~/.claude.json:/home/sprrw/.claude.json \
            DOCKERIMG \
            ${pkgs.claude-code}/bin/claude --dangerously-skip-permissions "$@"
        '';
      })
      (pkgs.writeShellApplication {
        name = "qwen-code";
        text = ''
          mkdir -p ~/.qwen

          ${createOllamaBridge}

          OLLAMA_HOST="''${OLLAMA_HOST:-http://host.docker.internal:11434}"

          ${config.sprrw.sandboxing.runDocker} \
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

    services.ollama = {
      enable = true;
      package = pkgs.ollama-cuda;
      environmentVariables = {
        OLLAMA_KEEP_ALIVE = "5m";
        OLLAMA_CONTEXT_LENGTH = "16000";
      };
      host = "0.0.0.0"; # for docker. protected by firewall anyway
    };
  };
}
