{
  config,
  lib,
  pkgs,
  inputs,
  mkSandbox,
  ...
}:

{
  options = {
    sprrw.sec.pwnproxy.enable = lib.mkEnableOption "pwnproxy";
  };

  config = lib.mkIf config.sprrw.sec.pwnproxy.enable {
    home.packages =
      let
        pwnproxy = inputs.nvim-http-client.packages."${pkgs.stdenv.hostPlatform.system}".default;
      in
      [
        (mkSandbox {
          name = "pwnproxy";
          prog = "${pwnproxy}/bin/mitmproxy";
          shareCwd = true;
          sharedPaths = [
            {
              hostPath = "$HOME/.mitmproxy";
              boxPath = "/home/sprrw/.mitmproxy";
              ro = false;
              type = "dir";
            }
          ];
          network = true;
        })
        (
          let
            src = pkgs.writeTextDir "urlenc.py" ''
              #!/usr/bin/env python3

              import argparse
              import sys
              import urllib.parse

              parser = argparse.ArgumentParser(description="URL encode/decode stdin.")
              parser.add_argument("-a", "--all", action="store_true",
                help="URL encode all characters, not just special ones")
              parser.add_argument("-d", "--decode", action="store_true",
                help="URL decode instead of encode")
              args = parser.parse_args()

              data = sys.stdin.read()

              if args.decode:
                result = urllib.parse.unquote(data)
              elif args.all:
                result = "".join(f"%{b:02X}" for b in data.encode())
              else:
                result = urllib.parse.quote(data)

              sys.stdout.write(result)
            '';
          in
          pkgs.stdenv.mkDerivation {
            pname = "urlenc";
            version = "0.1.0";

            inherit src;

            buildInputs = [ pkgs.python3 ];

            dontBuild = true;

            installPhase = ''
              install -D urlenc.py $out/bin/urlenc

              substituteInPlace $out/bin/urlenc \
                --replace '#!/usr/bin/env python3' '#!${pkgs.python3}/bin/python3'
            '';
          }
        )
      ];
  };
}
