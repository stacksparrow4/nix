{
  nixpkgs-inputs ? { },
  pkgs ? import <nixpkgs> nixpkgs-inputs,
  impacket ? pkgs.python3Packages.impacket,
}:

pkgs.python3Packages.buildPythonPackage rec {
  pname = "bloodhound-ce";
  version = "1.8.0";
  pyproject = true;

  src = pkgs.fetchPypi {
    inherit version;
    pname = "bloodhound_ce";
    hash = "sha256-9mPWGB4qGrjenVeUgBFmLipHiA2MrKm4U2mn767ROnA=";
  };

  nativeBuildInputs = with pkgs.python3Packages; [ setuptools ];

  propagatedBuildInputs =
    (with pkgs.python3Packages; [
      dnspython
      ldap3
      pycryptodome
    ])
    ++ [ impacket ];

  doCheck = false;
}
