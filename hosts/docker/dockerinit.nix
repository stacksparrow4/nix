{
  pkgs,
  inputs,
}:

# The output of this file is a script that will be run inside a docker container that has a mounted nix store. The script should end in spawning bash after setting up the home directory properly
let
  homeConfig = (inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;

    modules = [
      ./home/default.nix
    ];

    extraSpecialArgs = { inputs = inputs; };
  }).activationPackage;
in pkgs.writeShellScript "dockerinit" ''
  set -e

  cp -r "${homeConfig}/home-files/".* ~/
  chmod -R u+w ~

  export TERM=alacritty
  export PATH="$PATH:${homeConfig}/home-path/bin"
  exec "$@"
''
