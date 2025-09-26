{ pkgs, lib, config, ... }:

{
  options.sprrw.sec.burp = {
    enable = lib.mkEnableOption "burp";

    pro = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = let
    cfg = config.sprrw.sec.burp;
  in lib.mkIf cfg.enable {
    home.packages = [
      (pkgs.burpsuite.override {
        proEdition = cfg.pro;
      })
    ];
  };
}
