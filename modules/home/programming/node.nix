{
  flake.homeModules.programming-node =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        nodejs_22
      ];
    };
}
