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
    ];

    services.ollama = {
      enable = true;
      package = pkgs.ollama-cuda;
      environmentVariables.OLLAMA_KEEP_ALIVE = "1m";
    };
  };
}
