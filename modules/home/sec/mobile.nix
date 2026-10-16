{ moduleWithSystem, ... }:

{
  flake.homeModules.mobile = moduleWithSystem (
    { self', ... }:
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.frida-tools
        self'.packages.apktool
        self'.packages.jadx
        pkgs.android-tools
      ];
    }
  );
}
