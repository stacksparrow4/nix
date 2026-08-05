{ moduleWithSystem, ... }:

{
  flake.homeModules.sec-scanning = moduleWithSystem (
    { self', ... }:
    { pkgs, ... }:
    {
      home.packages =
        (with pkgs; [
          nmap
          masscan
          rustscan
        ])
        ++ (with self'.packages; [
          nuclei
          sqlmap
          feroxbuster
          ffuf
          shortscan
          gau
          naabu
          clairvoyance
          sourcemapper
          subfinder
          vulnx
          smuggler
        ]);
    }
  );
}
