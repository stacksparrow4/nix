{ pkgs, lib, config, ... }@inputs:

{
  options = {
    sprrw.sec.windows.netexec.enable = lib.mkEnableOption "netexec";
  };

  config = let
    pkgs = import ./pinned-pkgs.nix { system = inputs.pkgs.system; };
  in lib.mkIf config.sprrw.sec.windows.netexec.enable {
    home.packages = [(
      let
        python = pkgs.python312.override {
          self = python;
          packageOverrides = self: super: {
            impacket = super.impacket.overridePythonAttrs {
              version = "0.13.0.dev0+20250527.165759.abfaea2b";
              src = pkgs.fetchFromGitHub {
                owner = "Pennyw0rth";
                repo = "impacket";
                rev = "abfaea2b613cab86a94ae7e5edbf5801ef347f30";
                hash = "sha256-LUmo20bRScg1Pd4c4tqtH8pxHk9uC5sLdyjOLZC0exA=";
              };
              # Fix version to be compliant with Python packaging rules
              postPatch = ''
                substituteInPlace setup.py \
                  --replace 'version="{}.{}.{}.{}{}"' 'version="{}.{}.{}"'
              '';
            };
            bloodhound-py = super.bloodhound-py.overridePythonAttrs {
              pname = "bloodhound-ce";
              version = "1.8.0";

              src = pkgs.fetchPypi {
                version = "1.8.0";
                pname = "bloodhound_ce";
                hash = "sha256-9mPWGB4qGrjenVeUgBFmLipHiA2MrKm4U2mn767ROnA=";
              };
            };
          };
        };
      in
      python.pkgs.buildPythonApplication {
        pname = "netexec";
        version = "1.4.0";
        pyproject = true;

        src = pkgs.fetchFromGitHub {
          owner = "Pennyw0rth";
          repo = "NetExec";
          rev = "714c44bac8959861095c6ebfc5b3695f9a025b97";
          hash = "sha256-FQ4xETy3UEN6vZ2oBKJhvc64g5MrsdxHD9mUMvrR2+A=";
        };

        pythonRelaxDeps = true;

        pythonRemoveDeps = [
          # Fail to detect dev version requirement
          "neo4j"
        ];

        postPatch = ''
          substituteInPlace pyproject.toml \
            --replace-fail " @ git+https://github.com/Pennyw0rth/impacket.git" "" \
            --replace-fail " @ git+https://github.com/wbond/oscrypto" "" \
            --replace-fail " @ git+https://github.com/Pennyw0rth/NfsClient" ""
        '';

        build-system = with python.pkgs; [
          poetry-core
          poetry-dynamic-versioning
        ];

        dependencies = with python.pkgs; [
          jwt
          aardwolf
          aioconsole
          aiosqlite
          argcomplete
          asyauth
          beautifulsoup4
          bloodhound-py
          dploot
          dsinternals
          impacket
          lsassy
          masky
          minikerberos
          msgpack
          msldap
          neo4j
          paramiko
          pyasn1-modules
          pylnk3
          pynfsclient
          pypsrp
          pypykatz
          python-dateutil
          python-libnmap
          pywerview
          requests
          rich
          sqlalchemy
          termcolor
          terminaltables
          xmltodict
        ];

        nativeCheckInputs = with python.pkgs; [ pytestCheckHook ] ++ [ writableTmpDirAsHomeHook ];

        # Tests no longer works out-of-box with 1.3.0
        doCheck = false;
      }
    )];
  };
}
