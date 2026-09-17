{
  flake.homeModules.ai-llama-qwen =
    { pkgs, ... }:
    {
      sprrw.ai = {
        pi.extraModels."llama.cpp".modelOverrides = {
          "qwen3.5" = {
            reasoning = true;
            compat.thinkingFormat = "qwen-chat-template";
          };
          "qwen3.6" = {
            reasoning = true;
            compat.thinkingFormat = "qwen-chat-template";
          };
          "swift" = {
            reasoning = true;
            thinkingLevelMap = {
              off = "off";
              minimal = "low";
              low = "low";
              medium = "medium";
              high = "xhigh";
              xhigh = "xhigh";
              max = "xhigh";
            };
            compat = {
              thinkingFormat = "chat-template";
              chatTemplateKwargs = {
                enable_thinking = {
                  "$var" = "thinking.enabled";
                };
                preserve_thinking = true;
                reasoning_effort = {
                  "$var" = "thinking.effort";
                  omitWhenOff = true;
                };
              };
            };
          };
        };

        llama.models = [
          {
            name = "qwen3.5";
            path = pkgs.fetchurl {
              url = "https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/main/Qwen3.5-9B-UD-Q3_K_XL.gguf";
              hash = "sha256-quCHnhvpnOk/DVYhf4GFo5niWtaKjrvAlfNicGKDBi8=";
            };
            options = {
              ctx-size = 16384;
              jinja = true;
            };
          }
          {
            name = "qwen3.6";
            path = pkgs.fetchurl {
              url = "https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/resolve/main/Qwen3.6-35B-A3B-UD-Q4_K_M.gguf";
              hash = "sha256-rA4sEYngVfqjbv82FYDnnFvW+Odr/7TOVH8WfVPjGmE=";
            };
            options = {
              ctx-size = 16384;
              jinja = true;
            };
          }
          {
            name = "swift";
            path = pkgs.fetchurl {
              url = "https://huggingface.co/ukisai/Swift-Qwen3.8-27B-GGUF/resolve/main/Swift-Qwen3.8-27B-Q4_K_M.gguf";
              hash = "sha256-rVgR4pFDG9DeHOwMQASl6smNrumFCILtrGmoIyCeiKs=";
            };
            options = {
              ctx-size = 8192;
              spec-type = "draft-mtp";
              spec-draft-n-max = 2;
              jinja = true;
            };
          }
        ];
      };
    };
}
