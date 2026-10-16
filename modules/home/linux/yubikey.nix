{
  flake.homeModules.yubikey =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.yubioath-flutter ];
    };
}
