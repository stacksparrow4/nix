{
  pkgs ? import <nixpkgs-unstable> { },
  crane,
}:

let
  pi-unsandboxed = import ../pi { inherit pkgs; };
  pi-boxed = (import ../rust { inherit pkgs crane; }).pi-boxed;
in
pkgs.writeShellApplication {
  name = "pi";
  text = ''
    ${pi-boxed}/bin/pi ${pi-unsandboxed}/bin/pi "$@"
  '';
}
