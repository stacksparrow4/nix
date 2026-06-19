{
  pkgs,
  ...
}:

{
  _module.args.mkLlama =
    {
      name,
      model,
      context,
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
          --no-warmup -ngld all \
          --host /tmp/llama-cpp/llama.sock \
          -c ${builtins.toString context} \
          "$@"
      '';
    };

  # models = [
  #   {
  #     name = "qwen3.5";
  #     model = pkgs.fetchurl {
  #       url = "https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/main/Qwen3.5-9B-Q4_K_M.gguf";
  #       hash = "sha256-A7dHJ6hgpWM44ELEQguz8Esv7Fc0F19MufqFPa9St+g=";
  #     };
  #   }
  #   {
  #     name = "qwen3.6";
  #     model = pkgs.fetchurl {
  #       url = "https://huggingface.co/unsloth/Qwen3.6-27B-GGUF/resolve/main/Qwen3.6-27B-Q4_K_M.gguf";
  #       hash = "sha256-XtYNCvRlCoVLF1W9OS+a70hyZD3CWiVLxoBD+mODkqA=";
  #     };
  #   }
  # ];
}
