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
        doCheck = false;
      }
      // extra
    );
in
{
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
