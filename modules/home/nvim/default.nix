{ moduleWithSystem, ... }:

{
  flake.homeModules.nvim = moduleWithSystem (
    { self', ... }:
    { pkgs, ... }:
    {
      home.packages = [
        (if pkgs.stdenv.hostPlatform.isLinux then self'.packages.nvim else self'.packages.nvim-unboxed)
      ];

      sprrw.term.shellExtra = ''
        # Necessary because of nix path order
        alias vi='nvim'
        alias vim='nvim'
      '';
    }
  );
}
