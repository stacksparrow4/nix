{ pkgs, lib, config, ... }:

{
  options.sprrw.ai = {
    enable = lib.mkEnableOption "ai";

    ollama-server-url = lib.mkOption {
      type = lib.types.str;
      default = "http://localhost:11434";
    };
  };

  config = let
    cfg = config.sprrw.ai;
  in lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      aichat
      (pkgs.writeShellApplication {
        name = "claude";
        # claude mcp add brave-search -e BRAVE_API_KEY=BSA_your_key_here -- npx -y @brave/brave-search-mcp-server
        text = let
          claudeConfigured = pkgs.writeShellApplication {
            name = "claude";
            text = ''
              export ANTHROPIC_AUTH_TOKEN=ollama
              export ANTHROPIC_BASE_URL=${config.sprrw.ai.ollama-server-url}

              # disallowed-tools WebSearch is because we are using brave search instead
              "${pkgs.claude-code}/bin/claude" --model qwen3-coder:30b --dangerously-skip-permissions --disallowed-tools WebSearch "$@"
            '';
          };
          claudeBoxed = config.sprrw.sandboxing.runDockerBin {
            binName = "claude";
            beforeTargetArgs = config.sprrw.sandboxing.recipes.pwd_starter + " -v ~/.claude:/home/sprrw/.claude -v ~/.claude.json:/home/sprrw/.claude.json";
            afterTargetArgs = "${claudeConfigured}/bin/claude";
          };
        in ''
          mkdir -p ~/.claude
          touch ~/.claude.json

          ${claudeBoxed}/bin/claude "$@"
        '';
      })
    ];

    services.ollama = {
      enable = true;
      package = pkgs.ollama-cuda;
      environmentVariables.OLLAMA_KEEP_ALIVE = "5m";
    };
  };
}
