{
  pkgs,
}:

let
  pi-remote-script = pkgs.python3Packages.buildPythonApplication {
    pname = "pi-remote";
    version = "0.1.0";

    src = ./pi-remote.py;

    dontUnpack = true;
    format = "other";

    installPhase = ''
      install -D $src $out/bin/pi-remote
    '';
  };
in
  pi-remote-script
