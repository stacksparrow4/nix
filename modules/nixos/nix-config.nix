{ inputs, ... }:

{
  flake.modules.nixos.nix-config =
    { pkgs, ... }:
    let
      nixpkgsConfig = import ../../nixpkgs-config.nix;
    in
    {
      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];

        builders-use-substitutes = true;

        extra-substituters = [
          "https://noctalia.cachix.org"
        ];
        extra-trusted-public-keys = [
          "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
        ];
      };

      nixpkgs.config = nixpkgsConfig;

      _module.args.pkgsUnstable = import inputs.nixpkgs-unstable {
        system = pkgs.stdenv.hostPlatform.system;
        config = nixpkgsConfig;
      };

      nix.registry.nixpkgs.flake = inputs.nixpkgs;
      nix.registry.home-manager.flake = inputs.home-manager;
      nix.channel.enable = false;

      nix.nixPath = [
        "nixpkgs=${inputs.nixpkgs}"
        "nixpkgs-unstable=${inputs.nixpkgs-unstable}"
      ];

      nix.extraOptions = ''
        !include /home/sprrw/.local/nix-access-tokens.conf
      '';

      programs.nix-ld.enable = true;
    };
}
