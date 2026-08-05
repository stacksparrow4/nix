{
  flake.homeModules.linux-yubikey =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.yubioath-flutter ];
    };
}
