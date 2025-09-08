{ pkgs, lib, config, ... }:

{
  options.sprrw.burpPro = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf config.sprrw.packages.installGuiPackages {
    home.packages = [
      (
        pkgs.burpsuite.override {
          proEdition = config.sprrw.burpPro;
        }
      )
    ];
  };
}
