# fetchHF downloads a single file from a HuggingFace repo as a fixed-output
# derivation. Like mkSandbox it only needs `pkgs`, so it is a perSystem module
# argument rather than a home aspect.
{
  perSystem =
    { pkgs, ... }:
    {
      _module.args.fetchHF =
        {
          repo,
          filename,
          revision,
          hash,
        }:
        pkgs.stdenv.mkDerivation {
          name = filename;

          nativeBuildInputs = [
            pkgs.cacert
            (pkgs.python3.withPackages (ps: [
              ps.huggingface-hub
              ps.hf-xet
            ]))
          ];

          outputHashMode = "flat";
          outputHashAlgo = "sha256";
          outputHash = hash;

          buildCommand = ''
            export HOME="$TMPDIR"
            export HF_HOME="$TMPDIR/hf"
            export HF_XET_CACHE="$TMPDIR/xet"
            export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
            export HF_HUB_DISABLE_TELEMETRY=1
            export HF_HUB_DISABLE_PROGRESS_BARS=1
            mkdir -p "$HF_HOME" "$HF_XET_CACHE" "$TMPDIR/dl"

            hf download ${pkgs.lib.escapeShellArg repo} ${pkgs.lib.escapeShellArg filename} \
              --revision ${pkgs.lib.escapeShellArg revision} \
              --local-dir "$TMPDIR/dl"

            mv "$TMPDIR/dl/${filename}" "$out"
          '';
        };
    };
}
