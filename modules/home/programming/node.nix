{
  flake.homeModules.programming-node =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        nodejs_22
        typescript-language-server
      ];
    };
}
