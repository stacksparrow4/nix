{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.sprrw.ai.pi = {
    enable = lib.mkEnableOption "pi";
  };

  config =
    let
      cfg = config.sprrw.ai.pi;
      piArgs = {
        sharedPaths = [
          {
            hostPath = "$HOME/.pi";
            boxPath = "/home/sprrw/.pi";
            ro = false;
            type = "dir";
          }
        ];
        downgradeTerm = true;
        stdin = true;
        tty = true;
        network = true;
        hostNetwork = true;
        prog = "${pkgs.pi-coding-agent}/bin/pi";
      };
    in
    lib.mkIf cfg.enable {
      home.file.".pi/agent/models.json".text = builtins.toJSON {
        providers = (
          if config.sprrw.ai.llama-cpp.enable then
            {
              ollama = {
                baseUrl = "http://localhost:8033/v1";
                api = "openai-completions";
                apiKey = "llama";
                models = [
                  {
                    id = "default";
                    contextWindow = config.sprrw.ai.llama-cpp.context;
                  }
                ];
              };
            }
          else
            { }
        );
      };

      home.packages = lib.mkMerge [
        [
          (config.sprrw.sandbox.create (
            piArgs
            // {
              name = "pi-tmp";
            }
          ))
          (config.sprrw.sandbox.create (
            piArgs
            // {
              name = "pi";
              shareCwd = true;
            }
          ))
        ]
      ];
    };
}
