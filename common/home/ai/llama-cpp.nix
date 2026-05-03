{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.sprrw.ai.llama-cpp = {
    enable = lib.mkEnableOption "llama-cpp";

    reasoning = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    context = lib.mkOption {
      type = lib.types.int;
      default = 65536;
    };
  };

  config =
    let
      cfg = config.sprrw.ai.llama-cpp;
      llama-help = pkgs.writeShellApplication {
        name = "llama-help";
        text = ''
          podman run --rm -it --network none ghcr.io/ggml-org/llama.cpp:server-cuda13 --help
        '';
      };
      llama-cpp = pkgs.writeShellApplication {
        name = "llama-cpp";
        text =
          let
            model = pkgs.fetchurl {
              url = "https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/main/Qwen3.5-9B-Q4_K_M.gguf";
              hash = "sha256-A7dHJ6hgpWM44ELEQguz8Esv7Fc0F19MufqFPa9St+g=";
            };
          in
          ''
            rm /tmp/llama-cpp/llama.sock || true
            mkdir -p /tmp/llama-cpp
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
              --reasoning ${if cfg.reasoning then "on" else "off"} -c ${builtins.toString cfg.context} \
              "$@"
          '';
      };
    in
    lib.mkIf cfg.enable {
      home.packages = [
        llama-help
        (pkgs.writeShellApplication {
          name = "llama-start";
          text = ''
            systemctl start --user llama-cpp.service
            systemctl start --user llama-cpp-tcp.service
          '';
        })
        (pkgs.writeShellApplication {
          name = "llama-stop";
          text = ''
            systemctl stop --user llama-cpp.service
            systemctl stop --user llama-cpp-tcp.service
          '';
        })
        (pkgs.writeShellApplication {
          name = "llama-logs";
          text = ''
            journalctl --user -u llama-cpp.service -f
          '';
        })
      ];

      systemd.user.services = {
        llama-cpp = {
          Unit = {
            Description = "llama-cpp server";
            After = [ "network.target" ];
          };
          Service = {
            Type = "exec";
            ExecStart = "/usr/bin/env PATH=/run/current-system/sw/bin ${llama-cpp}/bin/llama-cpp";
            Restart = "on-failure";
            RestartSec = "5s";
          };
        };
        llama-cpp-tcp = {
          Unit = {
            Description = "llama-cpp tcp forwarder";
            After = [ "network.target" ];
          };
          Service = {
            Type = "exec";
            ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:8033,reuseaddr,fork UNIX-CONNECT:/tmp/llama-cpp/llama.sock";
            Restart = "on-failure";
            RestartSec = "5s";
          };
        };
      };
    };
}
