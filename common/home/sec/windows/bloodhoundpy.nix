{ pkgs, lib, config, ... }@inputs:

{
  options = {
    sprrw.sec.windows.bloodhoundpy.enable = lib.mkEnableOption "bloodhoundpy";
  };

  config = let
    pkgs = import ./pinned-pkgs.nix { system = inputs.pkgs.system; };
  in lib.mkIf config.sprrw.sec.windows.bloodhoundpy.enable {
    home.packages = [(
      pkgs.python3Packages.buildPythonPackage rec {
        pname = "bloodhound-py";
        version = "1.8.0";
        pyproject = true;

        src = pkgs.fetchPypi {
          inherit version;
          pname = "bloodhound_ce";
          hash = "sha256-9mPWGB4qGrjenVeUgBFmLipHiA2MrKm4U2mn767ROnA=";
        };

        nativeBuildInputs = with pkgs.python3Packages; [ setuptools ];

        propagatedBuildInputs = with pkgs.python3Packages; [
          dnspython
          impacket
          ldap3
          pycryptodome
        ];

        doCheck = false;
      }
    )];
  };
}
