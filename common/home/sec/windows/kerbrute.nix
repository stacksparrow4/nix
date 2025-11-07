{ pkgs, lib, config, ... }@inputs:

{
  options = {
    sprrw.sec.windows.kerbrute.enable = lib.mkEnableOption "kerbrute";
  };

  config = let
    pkgs = import ./pinned-pkgs.nix { system = inputs.pkgs.stdenv.hostPlatform.system; };
  in lib.mkIf config.sprrw.sec.windows.kerbrute.enable {
    home.packages = [(
      pkgs.buildGoModule {
        pname = "kerbrute";
        version = "1.0.3";

        src = pkgs.fetchFromGitHub {
          owner = "ropnop";
          repo = "kerbrute";
          tag = "v1.0.3";
          hash = "sha256-HC7iCu16iGS9/bEXfvRLG9cXns6E+jZvqbIaN9liFB4=";
        };

        vendorHash = "sha256-8/3NyKz0rLo3Js6iwzDUki6K/BrljLkl4K9tNgK59XA=";
      }
    )];
  };
}
