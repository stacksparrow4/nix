{ pkgs, ... }:

{
  imports = [
    ./mkpythonenv.nix
    ./mkwindowsenv.nix
  ];

  home.packages = [(pkgs.writeShellScriptBin "windows-yaml.sh" (builtins.readFile ./windows-yaml.sh))];
}
