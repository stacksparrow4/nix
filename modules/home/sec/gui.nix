{
  flake.modules.homeManager.sec-gui =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.binaryninja-free
        pkgs.ghidra
        pkgs.wireshark
      ];
    };
}
