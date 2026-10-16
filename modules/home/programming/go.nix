{
  flake.homeModules.go =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        go
        gopls
      ];
    };
}
