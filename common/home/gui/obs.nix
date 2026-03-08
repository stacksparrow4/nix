{ pkgs, lib, config, ... }:

{
  options.sprrw.gui.obs = {
    enable = lib.mkEnableOption "obs";
  };

  config = let
    cfg = config.sprrw.gui.obs;
  in lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      (wrapOBS {
        plugins = with obs-studio-plugins; [
          obs-websocket
        ];
      })
      (
        import ./obs-cli-tool/default.nix { inherit pkgs; }
      )
    ];
  };
}
