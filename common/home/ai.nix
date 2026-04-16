{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.sprrw.ai = {
    enable = lib.mkEnableOption "ai";

    claude.enable = lib.mkEnableOption "claude";
    qwen-remote.enable = lib.mkEnableOption "qwen-remote";
  };

  config =
    let
      cfg = config.sprrw.ai;
    in
    lib.mkIf cfg.enable {
      home.packages = lib.mkMerge [
        (with pkgs; [
          ollama
          aichat
        ])

        (
          let
            claudeSandboxArgs = {
              sharedPaths = [
                {
                  hostPath = "$HOME/.local/claude-vm/.claude";
                  boxPath = "/home/sprrw/.claude";
                  ro = false;
                  type = "dir";
                }
                {
                  hostPath = "$HOME/.local/claude-vm/.claude.json";
                  boxPath = "/home/sprrw/.claude.json";
                  ro = false;
                  type = "file";
                }
              ];
              downgradeTerm = true;
              stdin = true;
              tty = true;
              network = true;
              prog = "${pkgs.claude-code}/bin/claude --dangerously-skip-permissions";
            };
          in
          lib.mkIf cfg.claude.enable [
            (config.sprrw.sandbox.create (
              claudeSandboxArgs
              // {
                name = "claude-code-tmp";
              }
            ))

            (config.sprrw.sandbox.create (
              claudeSandboxArgs
              // {
                name = "claude-code";
                shareCwd = true;
              }
            ))
            (config.sprrw.sandbox.create (
              claudeSandboxArgs
              // {
                # TODO: version match with the VM instead of assuming path same as host
                name = "claude-code-vm";
                type = "vm";
                sharedPaths = [
                  {
                    hostPath = "$HOME/.local/claude-vm";
                    boxPath = "/mnt/claude";
                    ro = false;
                    type = "dir";
                  }
                ];
                shareCwd = true;
                insideBeforeScript = ''
                  ln -s /mnt/claude/.claude ~/.claude
                  ln -s /mnt/claude/.claude.json ~/.claude.json
                  export TERM=xterm-256color
                  export COLORTERM=truecolor
                '';
              }
            ))
          ]
        )

        (
          let
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
          lib.mkMerge [
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

            (lib.mkIf cfg.qwen-remote.enable [
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
          ]
        )

      ];
    };
}
