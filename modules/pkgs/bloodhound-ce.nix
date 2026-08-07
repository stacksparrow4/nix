{
  perSystem =
    {
      pkgs,
      mkSandboxPkg,
      config,
      ...
    }:
    let
      mkBloodhoundCE =
        impacket:
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
        };
    in
    {
      packages = rec {
        bloodhound-ce-unboxed = mkBloodhoundCE pkgs.python3Packages.impacket;
        bloodhound-ce = mkSandboxPkg {
          name = "bloodhound-ce";
          shareCwd = true;
          network = true;
          prog = "${bloodhound-ce-unboxed}/bin/bloodhound-ce-python";
        };

        bloodhound-ce-netexec-unboxed = mkBloodhoundCE config.packages.netexec-impacket;
      };
    };
}
