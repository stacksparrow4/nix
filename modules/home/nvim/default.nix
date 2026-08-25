{ moduleWithSystem, ... }:

{
  flake.homeModules.nvim = moduleWithSystem (
    { self', ... }:
    { pkgs, ... }:
    {
      home.packages = [
        self'.packages.nvim
        (pkgs.writeShellScriptBin "nvim-unboxed" ''
          exec ${self'.packages.nvim-unboxed} "$@"
        '')
      ];

      home.sessionVariables.EDITOR = "nvim";

      sprrw.term.shellExtra = ''
        # Necessary because of nix path order
        alias vi='nvim'
        alias vim='nvim'
      '';
    }
  );
}
