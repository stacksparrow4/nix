{
  flake.homeModules.typst =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        typst
      ];
    };
}
