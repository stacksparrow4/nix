{ pkgs, lib, config, ... }:

{
  options.sprrw.ai = {
    enable = lib.mkEnableOption "ai";
  };

  config = let
    cfg = config.sprrw.ai;
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
    ];
  };
}
