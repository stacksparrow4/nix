{
  pkgs ? import <nixpkgs> {},
}:

pkgs.buildNpmPackage (finalAttrs: {
  pname = "obs-cli-tool";
  version = "0.1.0";

  src = ./.;

  npmDepsHash = "sha256-29UJfQ78tRUigOBCzaNZY7K26a+jovtDK8xNAsnx570=";

  # The prepack script runs the build script, which we'd rather do in the build phase.
  npmPackFlags = [ "--ignore-scripts" ];

  dontNpmBuild = true;
})
