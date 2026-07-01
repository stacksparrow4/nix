# this file is used as a compatibility wrapper around nix-update
# nix-update is designed to work with nixpkgs, so we make this file take nixpkgs args and output attributes similar to nixpkgs

nixpkgs-inputs:

{
  pi = import ./pi { inherit nixpkgs-inputs; };
  netexec = import ./netexec { inherit nixpkgs-inputs; };
  netexec-impacket = import ./netexec-impacket { inherit nixpkgs-inputs; };
}
