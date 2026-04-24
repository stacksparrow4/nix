{
  pkgs,
  lib,
  config,
  ...
}:

{
  imports = [
    ./claude.nix
    ./qwen.nix
    ./llama-cpp.nix
    ./pi.nix
  ];

  options.sprrw.ai.enable = lib.mkEnableOption "ai";

  config =
    let
      cfg = config.sprrw.ai;
    in
    lib.mkIf cfg.enable {
      home.packages = with pkgs; [ aichat ];
    };
}
