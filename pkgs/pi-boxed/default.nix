# The pi wrapper: pi-boxed sandboxes the real (unsandboxed) pi agent.
#
# The Rust source now lives in ../rust, as a workspace member sharing the command
# bridge with `sandbox`.
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
