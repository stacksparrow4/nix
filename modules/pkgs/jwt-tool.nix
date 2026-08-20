{
  perSystem =
    {
      pkgs,
      lib,
      mkSandbox,
      ...
    }:
    let
      cprint = pkgs.python3Packages.buildPythonPackage rec {
        pname = "cprint";
        version = "1.2.2";
        format = "setuptools";

        src = pkgs.fetchPypi {
          inherit pname version;
          hash = "sha256-g0aSdNskk5snqbOgPVKY/sbwdAjDF13A/CHVuiBvUcg=";
        };

        pythonImportsCheck = [ "cprint" ];
      };

      updatedPackages = pkgs.python3Packages // {
        inherit cprint;
      };

      jwttool = pkgs.python3Packages.buildPythonPackage rec {
        pname = "jwt_tool";
        version = "0.1.0";
        format = "other";

        src = pkgs.fetchFromGitHub {
          owner = "ticarpi";
          repo = "jwt_tool";
          rev = "3bc7407cf2222d6a821dcc19c776e5a1b1cb9a9b";
          hash = "sha256-hro7Big55b26BW3hyr8pE7f8vq/ley+M4Yiuk9SJObg=";
        };

        propagatedBuildInputs =
          let
            reqs = builtins.filter (s: s != "" && !(lib.hasPrefix "#" s)) (
              lib.splitString "\r\n" (builtins.readFile (src + "/requirements.txt"))
            );
          in
          builtins.map (name: updatedPackages.${name}) reqs;

        installPhase = ''
          runHook preInstall
          mkdir -p $out/bin
          cp -v ./jwt_tool.py $out/bin/${pname}
          chmod +x $out/bin/${pname}
          patchShebangs $out/bin
          runHook postInstall
        '';
      };
    in
    {
      packages = {
        jwt-tool-unwrapped = jwttool;
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        jwt-tool = mkSandbox {
          name = "jwt_tool";
          sharedPaths = [
            {
              hostPath = "$HOME/.jwt_tool";
              boxPath = "~/.jwt_tool";
              ro = false;
              type = "dir";
            }
          ];
          shareCwd = true;
          prog = "${jwttool}/bin/jwt_tool";
        };
      };
    };
}
