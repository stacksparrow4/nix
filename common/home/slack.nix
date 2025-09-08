{ pkgs, lib, config, ... }:

let cfg = config.sprrw.slack; in {
  options = {
    sprrw.slack.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [ slack ];
  };
}
