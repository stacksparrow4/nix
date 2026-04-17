{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.sprrw.ai.qwen = {
    enable = lib.mkEnableOption "qwen";
    enable-remote = lib.mkEnableOption "qwen-remote";
  };

  config =
    let
      cfg = config.sprrw.ai.qwen;
      qwenRemoteArgs = {
        sharedPaths = [
          {
            hostPath = "$HOME/.qwen";
            boxPath = "/home/sprrw/.qwen";
            ro = false;
            type = "dir";
          }
        ];
        envVars = [
          "OPENAI_API_KEY=ollama"
          "OPENAI_BASE_URL=\"$OLLAMA_HOST/v1\""
          "OPENAI_MODEL=\"qwen3-coder:30b\""
        ];
        downgradeTerm = true;
        stdin = true;
        tty = true;
        network = true;
        prog = "${pkgs.qwen-code}/bin/qwen --yolo";
      };
      qwenLocalArgs = qwenRemoteArgs // {
        envVars = [
          "OPENAI_API_KEY=notimportant"
          "OPENAI_BASE_URL=\"http://localhost:8033/v1\""
          "OPENAI_MODEL=\"notimportant\""
        ];
        hostNetwork = true;
      };
    in
    lib.mkIf cfg.enable {
      home.packages = lib.mkMerge [
        [
          (pkgs.writeShellApplication {
            name = "llama-cpp";
            text =
              let
                modelFile = "Qwen3.5-9B-Q4_K_M.gguf";
                defaultContext = 32768;
              in
              ''
                CONTEXT=${toString defaultContext}
                if [[ $# -eq 1 ]]; then
                  CONTEXT="$1"
                fi

                mkdir -p ~/.local/models

                if ! [[ -f ~/.local/models/${modelFile} ]]; then
                  echo "Model not found. Download using"
                  echo "wget -O ~/.local/models https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/main/Qwen3.5-9B-Q4_K_M.gguf"
                  exit 1
                fi

                docker run --rm -it \
                  --name llama-cpp \
                  -p 8033:8033 \
                  --gpus all \
                  -v ~/.local/models:/models \
                  ghcr.io/ggml-org/llama.cpp:server-cuda13 \
                  -m /models/${modelFile} \
                  -c "$CONTEXT" --no-warmup -ngld all \
                  --host 0.0.0.0 --port 8033
              '';
          })
          (config.sprrw.sandbox.create (
            qwenLocalArgs
            // {
              name = "qwen-code-tmp";
            }
          ))
          (config.sprrw.sandbox.create (
            qwenLocalArgs
            // {
              name = "qwen-code";
              shareCwd = true;
            }
          ))
        ]

        (lib.mkIf cfg.enable-remote [
          pkgs.ollama

          (config.sprrw.sandbox.create (
            qwenRemoteArgs
            // {
              name = "qwen-code-remote-tmp";
            }
          ))
          (config.sprrw.sandbox.create (
            qwenRemoteArgs
            // {
              name = "qwen-remote-code";
              shareCwd = true;
            }
          ))
        ])
      ];
    };
}
