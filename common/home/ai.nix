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
  in lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      aichat
      (pkgs.writeShellApplication {
        name = "claude-code";
        # claude mcp add brave-search -e BRAVE_API_KEY=BSA_your_key_here -- npx -y @brave/brave-search-mcp-server
        text = let
          claudeConfigured = pkgs.writeShellApplication {
            name = "claude";
            text = ''
              export ANTHROPIC_AUTH_TOKEN=ollama
              export ANTHROPIC_BASE_URL=${config.sprrw.ai.ollama-server-url}

              # disallowed-tools WebSearch is because we are using brave search instead
              "${pkgs.claude-code}/bin/claude" --model ${cfg.model} --dangerously-skip-permissions --disallowed-tools WebSearch "$@"
            '';
          };
          claudeBoxed = config.sprrw.sandboxing.runDockerBin {
            name = "claude";
            args = config.sprrw.sandboxing.recipes.pwd_starter +
              " -v ~/.claude:/home/sprrw/.claude -v ~/.claude.json:/home/sprrw/.claude.json" +
              " --network ollama-network" + 
              " --add-host host.docker.internal=\"$(docker network inspect ollama-network --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}')\"" +
              " DOCKERIMG" + 
              " ${claudeConfigured}/bin/claude";
          };
        in ''
          mkdir -p ~/.claude
          touch ~/.claude.json

          if ! docker network inspect ollama-network &>/dev/null; then
            docker network create --driver bridge --opt com.docker.network.bridge.name=br-ollama ollama-network
          fi

          ${claudeBoxed}/bin/claude "$@"
        '';
      })
    ];

    services.ollama = {
      enable = true;
      package = pkgs.ollama-cuda;
      environmentVariables = {
        OLLAMA_KEEP_ALIVE = "5m";
        OLLAMA_CONTEXT_LENGTH = "64000";
      };
      host = "0.0.0.0"; # for docker. protected by firewall anyway
    };
  };
}
