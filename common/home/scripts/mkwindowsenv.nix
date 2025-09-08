{ pkgs, inputs, ... }:

{
  home.packages = [(
    import ./shellnixcreator.nix {
      inherit pkgs;
      inherit inputs;
      scriptName = "mkwindowsenv";
      mkShellCmd = ''
        pkgs.mkShell {
          buildInputs = with pkgs.pkgsCross.mingwW64.buildPackages; [
            gcc
            clang-tools
            cmake
          ];
        }
      '';
    }
  )];
}
