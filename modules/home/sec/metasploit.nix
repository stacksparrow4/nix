{ moduleWithSystem, ... }:

{
  flake.homeModules.sec-metasploit = moduleWithSystem (
    { self', ... }:
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.metasploit
        self'.packages.metasm-shell
      ];
    }
  );
}
