{
  lib,
  config,
  self',
  ...
}:

{
  imports = [
    ./fetch-hf.nix
    ./llama-cpp.nix
    ./pi
  ];

  options.sprrw.ai.enable = lib.mkEnableOption "ai";

  config =
    let
      cfg = config.sprrw.ai;
    in
    lib.mkIf cfg.enable {
      home.packages = [ self'.packages.bx ];
    };
}
