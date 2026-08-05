{
  flake.homeModules.programming-typst =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        typst
        tinymist
        typstyle
      ];
    };
}
