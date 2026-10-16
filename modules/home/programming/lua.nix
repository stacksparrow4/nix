{
  flake.homeModules.lua =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        lua
        lua-language-server
      ];
    };
}
