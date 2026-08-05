{
  flake.homeModules.programming-xml =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        lemminx
      ];
    };
}
