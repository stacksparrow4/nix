{ moduleWithSystem, ... }:

{
  flake.homeModules.sec-metasploit = moduleWithSystem (
    { self', ... }:
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.metasploit
        self'.packages.msfscripts
      ];
    }
  );
}
