{ pkgs, lib, config, ... }:

{
  options.sprrw.ai = {
    enable = lib.mkEnableOption "ai";

    ollama-server-url = lib.mkOption {
      type = lib.types.str;
      default = "http://host.docker.internal:11434";
    };

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
        # claude mcp add brave-search -e BRAVE_API_KEY=BSA_your_key_here -- npx -y @brave/brave-search-mcp-server
        text = ''
          mkdir -p ~/.claude
          touch ~/.claude.json

          ${createOllamaBridge}

          # disallowed-tools WebSearch is because we are using brave search instead
          ${config.sprrw.sandboxing.runDocker} \
            ${config.sprrw.sandboxing.recipes.pwd_starter} \
            -v ~/.claude:/home/sprrw/.claude -v ~/.claude.json:/home/sprrw/.claude.json \
            --network ollama-network \
            --add-host host.docker.internal="$(docker network inspect ollama-network --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}')" \
            -e ANTHROPIC_AUTH_TOKEN=ollama \
            -e ANTHROPIC_BASE_URL=${config.sprrw.ai.ollama-server-url} \
            DOCKERIMG \
            ${pkgs.claude-code}/bin/claude --model ${cfg.model} --dangerously-skip-permissions --disallowed-tools WebSearch "$@"
        '';
      })
      (pkgs.writeShellApplication {
        name = "gemini";
        text = ''
          mkdir -p ~/.gemini

          ${config.sprrw.sandboxing.runDocker} ${config.sprrw.sandboxing.recipes.pwd_starter} -v ~/.gemini:/home/sprrw/.gemini DOCKERIMG ${pkgs.gemini-cli}/bin/gemini "$@"
        '';
      })
      (pkgs.writeShellApplication {
        name = "qwen-code";
        text = ''
          mkdir -p ~/.qwen

          ${createOllamaBridge}

          ${config.sprrw.sandboxing.runDocker} \
            ${config.sprrw.sandboxing.recipes.pwd_starter} \
            -v ~/.qwen:/home/sprrw/.qwen \
            --network ollama-network \
            --add-host host.docker.internal="$(docker network inspect ollama-network --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}')" \
            -e OPENAI_API_KEY=ollama \
            -e OPENAI_BASE_URL=${cfg.ollama-server-url}/v1 \
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
