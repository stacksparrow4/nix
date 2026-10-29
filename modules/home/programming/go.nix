{
  flake.modules.homeManager.go =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        go
        gopls
      ];
    };
}
