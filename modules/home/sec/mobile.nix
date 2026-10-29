{ moduleWithSystem, ... }:

{
  flake.modules.homeManager.mobile = moduleWithSystem (
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
