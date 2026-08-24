{
  perSystem =
    {
      pkgs,
      mkSandbox,
      ...
    }:
    let
      smugglerSrc = pkgs.fetchFromGitHub {
        owner = "defparam";
        repo = "smuggler";
        rev = "2be871e6151ce85167a277fab21c74c851d8b20b";
        hash = "sha256-ctRx81DL5orVioB+d22qSsEe9m5+CLU7VqmRmLBN4xs=";
      };

      smugglerSrcWithPayloadsLink = pkgs.runCommand "smuggler-src-linked" { } ''
        mkdir $out
        cd $out
        cp -r ${smugglerSrc}/* .
        chmod -R 755 .
        rm -rf payloads
        ln -s /payloads payloads
      '';
    in
    {
      packages = rec {
        smuggler-unboxed = pkgs.writeShellApplication {
          name = "smuggler";
          text = ''
            ${pkgs.python313}/bin/python3 ${smugglerSrcWithPayloadsLink}/smuggler.py "$@"
          '';
        };

        smuggler = mkSandbox {
          name = "smuggler";
          sharedPaths = [
            {
              hostPath = "$(pwd)/payloads";
              boxPath = "/payloads";
              ro = false;
              type = "dir";
            }
          ];
          network = true;
          prog = "${smuggler-unboxed}/bin/smuggler";
        };
      };
    };
}
