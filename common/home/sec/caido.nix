{ pkgs, lib, config, ... }:

{
  options.sprrw.sec.caido = {
    enable = lib.mkEnableOption "caido";
  };

  config = let
    cfg = config.sprrw.sec.caido;
    caidoOverridden = pkgs.caido.override { appVariants = [ "desktop" ]; };
    caidoDeriv = pkgs.runCommand "caido-wrapper" {} ''
      mkdir -p $out/share/applications
      cat ${caidoOverridden}/share/applications/caido.desktop | sed 's/Exec=.*/Exec=caido %U/' > $out/share/applications/caido.desktop
      ln -s ${caidoOverridden}/share/icons $out/share/icons
      ln -s ${caidoOverridden}/bin $out/bin
    '';
  in lib.mkIf cfg.enable {
    home.packages = [
      caidoDeriv
    ];
  };
}
