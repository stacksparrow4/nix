{ moduleWithSystem, ... }:

{
  flake.homeModules.gui-obs = moduleWithSystem (
    { self', ... }:
    { pkgs, ... }:
    {
      home.packages = [
        (pkgs.wrapOBS {
          plugins = with pkgs.obs-studio-plugins; [
            obs-websocket
          ];
        })
        self'.packages.obs-cli-tool
      ];
    }
  );
}
