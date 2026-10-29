{
  flake.modules.homeManager.yubikey =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.yubioath-flutter ];
    };
}
