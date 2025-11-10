{ pkgs, lib, config, ... }:

{
  options.sprrw.gui.brave = {
    enable = lib.mkEnableOption "brave";

    sandboxed = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = let
    cfg = config.sprrw.gui.brave;
  in lib.mkMerge [
    (lib.mkIf (cfg.enable && !cfg.sandboxed) {
      home.packages = with pkgs; [
        brave
      ];
    })

    (lib.mkIf (cfg.enable && cfg.sandboxed) {
      home.packages = [(
        let
          braveDeriv = config.sprrw.sandboxing.runDocker {
            cmd = "brave";
            shareX11 = true;
            netHost = true;
          };
        in
          pkgs.runCommand "brave-wrapped" {} ''
            mkdir -p $out/bin
            ln -s ${braveDeriv} $out/bin/brave
          ''
      )];
    })
  ];
}
