{ inputs, ... }:

{
  perSystem =
    {
      pkgs,
      pkgs-unstable,
      lib,
      ...
    }:
    let
      portable = [
        "bloodhound-ce"
        "interactsh"
        "llama-server"
        "netexec-impacket"
        "oob"
        "pi"
        "sprrw"
      ];

      linuxOnly = [
        "netexec"
        "pi-boxed"
        "portal-chooser"
        "sandbox"
      ];

      scope = lib.makeScope pkgs.newScope (self: {
        inherit pkgs pkgs-unstable;
        inherit (inputs) crane;

        bloodhound-ce = self.callPackage ./bloodhound-ce { };
        interactsh = self.callPackage ./interactsh { };
        llama-server = self.callPackage ./llama-server { };
        netexec = self.callPackage ./netexec { original-bloodhound-ce = self.bloodhound-ce; };
        netexec-impacket = self.callPackage ./netexec-impacket { };
        oob = self.callPackage ./oob { };
        pi = self.callPackage ./pi { };
        pi-boxed = self.callPackage ./pi-boxed { };
        portal-chooser = self.callPackage ./portal-chooser { };
        sandbox = self.callPackage ./sandbox { };
        sprrw = self.callPackage ./sprrw { };
      });
    in
    {
      packages = lib.getAttrs (
        portable ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux linuxOnly
      ) scope;
    };
}
