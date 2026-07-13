{
  pkgs,
  ...
}:

{
  _module.args = {
    mkLlama =
      {
        name,
        model,
        context,
        reasoning ? true,
      }:
      pkgs.writeShellApplication {
        inherit name;
        text = ''
          rm /tmp/llama-cpp/llama.sock || true
          mkdir -p /tmp/llama-cpp

          ${pkgs.socat}/bin/socat TCP-LISTEN:8033,reuseaddr,fork UNIX-CONNECT:/tmp/llama-cpp/llama.sock &
          SOCAT_PID=$!

          trap 'kill $SOCAT_PID 2>/dev/null; wait $SOCAT_PID 2>/dev/null' EXIT

          podman run --rm -it \
            --name llama-cpp \
            --gpus all \
            -v ${model}:/model.gguf \
            -v /tmp/llama-cpp:/tmp/llama-cpp \
            --network none \
            ghcr.io/ggml-org/llama.cpp:server-cuda13 \
            -m /model.gguf \
            --no-warmup \
            --host /tmp/llama-cpp/llama.sock \
            --reasoning ${if reasoning then "on" else "off"} \
            -c ${toString context} \
            "$@"
        '';
      };
    fetchHF =
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
