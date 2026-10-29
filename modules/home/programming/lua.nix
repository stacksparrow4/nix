{
  flake.modules.homeManager.lua =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        lua
        lua-language-server
      ];
    };
}
