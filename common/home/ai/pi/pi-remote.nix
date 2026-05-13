{
  pkgs,
  config,
  mkSandbox,
  extraModels,
  defaultExtensions,
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
  pi-remote-sandbox = import ./pi-sandbox.nix {
    inherit
      pkgs
      config
      mkSandbox
      extraModels
      ;
    name = "pi-remote-sandbox";
    system = "system-remote.md";
    tools = [ "command" ];
    extensions = defaultExtensions ++ [ "pi-remote.ts" ];
    network = true;
    extraMounts = [
      {
        hostPath = "$PIPEDIR";
        boxPath = "/tmp/pi-remote";
        type = "dir";
        ro = true;
      }
    ];
  };
in
pkgs.writeShellApplication {
  name = "pi-remote";
  text = ''
    ${pi-remote-script}/bin/pi-remote ${pi-remote-sandbox}/bin/pi-remote-sandbox "$@"
  '';
}
