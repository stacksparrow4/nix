{
  pkgs,
  lib,
  config,
  mkSandbox,
  ...
}:

{
  imports = [
    ./claude
    ./qwen.nix
    ./llama-cpp.nix
    ./pi
  ];

  options.sprrw.ai.enable = lib.mkEnableOption "ai";

  config =
    let
      cfg = config.sprrw.ai;
    in
    lib.mkIf cfg.enable {
      home.packages = with pkgs; [
        aichat
        (mkSandbox {
          name = "bx";
          sharedPaths = [
            {
              hostPath = "$HOME/.config/brave-search";
              boxPath = "/home/sprrw/.config/brave-search";
              ro = false;
              type = "dir";
            }
          ];
          network = true;
          prog = "${brave-search-cli}/bin/bx";
        })
      ];
    };
}
