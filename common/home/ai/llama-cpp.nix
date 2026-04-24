{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.sprrw.ai.llama-cpp = {
    enable = lib.mkEnableOption "llama-cpp";

    context = lib.mkOption {
      type = lib.types.int;
      default = 32768;
    };
  };

  config =
    let
      cfg = config.sprrw.ai.llama-cpp;
    in
    lib.mkIf cfg.enable {
      home.packages = [
        (pkgs.writeShellApplication {
          name = "llama-cpp";
          text =
            let
              model = pkgs.fetchurl {
                url = "https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/main/Qwen3.5-9B-Q4_K_M.gguf";
                hash = "sha256-A7dHJ6hgpWM44ELEQguz8Esv7Fc0F19MufqFPa9St+g=";
              };
            in
            ''
              podman run --rm -it \
                --name llama-cpp \
                -p 8033:8033 \
                --gpus all \
                -v ${model}:/model.gguf \
                ghcr.io/ggml-org/llama.cpp:server-cuda13 \
                -m /model.gguf \
                --no-warmup -ngld all \
                --host 0.0.0.0 --port 8033 \
                --reasoning off -c ${builtins.toString cfg.context} \
                "$@"
            '';
        })
      ];
    };
}
