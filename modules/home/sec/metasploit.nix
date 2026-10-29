{ moduleWithSystem, ... }:

{
  flake.modules.homeManager.metasploit = moduleWithSystem (
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
