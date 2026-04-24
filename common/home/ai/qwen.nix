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
