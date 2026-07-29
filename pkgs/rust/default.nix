# Cargo workspace holding the Rust tools that share the command bridge.
#
# `sandbox` and `pi` both serve the same unix-socket protocol (see
# crates/bridge), so the protocol lives in one crate rather than being
# reimplemented per binary. Both derivations reuse a single cargoArtifacts, so the
# shared dependency set is compiled once.
{
  pkgs ? import <nixpkgs-unstable> { },
  crane,
}:

let
  craneLib = crane.mkLib pkgs;

  src = craneLib.cleanCargoSource ./.;

  commonArgs = {
    inherit src;
    strictDeps = true;
  };

  cargoArtifacts = craneLib.buildDepsOnly commonArgs;

  crate =
    {
      name,
      member,
      extra ? { },
    }:
    craneLib.buildPackage (
      commonArgs
      // {
        inherit cargoArtifacts;
        pname = name;
        cargoExtraArgs = "--locked -p ${member}";
        # Both derivations use the whole workspace as source, so a change to either
        # crate rebuilds both. crane's fileSetForCrate pattern could narrow that if
        # build times ever matter.
        doCheck = false;
      }
      // extra
    );
in
{
  # Absolute store paths are baked in at build time rather than prefixed onto
  # PATH, so that sandboxes do not inherit these tools in their own PATH.
  #
  # qemu is deliberately absent and looked up on PATH at runtime, to keep its
  # ~1GB closure out of this package's closure.
  sandbox = crate {
    name = "sandbox";
    member = "sandbox";
    extra = {
      SANDBOX_SSH = pkgs.lib.getExe' pkgs.openssh "ssh";
      SANDBOX_SSH_KEYGEN = pkgs.lib.getExe' pkgs.openssh "ssh-keygen";
    };
  };

  pi-boxed = crate {
    name = "pi-boxed";
    member = "pi";
  };
}
