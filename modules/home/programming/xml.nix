{
  flake.homeModules.xml =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        lemminx
      ];
    };
}
