{ moduleWithSystem, ... }:

{
  flake.homeModules.sec-pwn = moduleWithSystem (
    { self', ... }:
    { pkgs, ... }:
    {
      home.packages = [
        self'.packages.pwndbg
        pkgs.gdb
        pkgs.lldb
        self'.packages.pwntools-env
        pkgs.patchelf
        self'.packages.pwninit
        self'.packages.ropr
        self'.packages.ROPgadget
      ];
    }
  );
}
