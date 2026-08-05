{
  flake.homeModules.programming-lua =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        lua
        lua-language-server
      ];
    };
}
