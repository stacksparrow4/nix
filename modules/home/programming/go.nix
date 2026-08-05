{
  flake.homeModules.programming-go =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        go
        gopls
      ];
    };
}
