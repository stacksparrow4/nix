{
  config,
  lib,
  pkgs,
  inputs,
  mkSandbox,
  ...
}:

{
  options.sprrw.sec.pwnproxy = {
    enable = lib.mkEnableOption "pwnproxy";

    config = lib.mkOption { default = { }; };
  };

  config =
    let
      cfg = config.sprrw.sec.pwnproxy;
    in
    lib.mkIf cfg.enable {
      home.file.".config/pwnproxy/tools".source = ./tools;
      home.file.".config/pwnproxy/config.json".text = builtins.toJSON (
        {
          ## TODO: figure out a safe way of using tmux while being sandboxed
          ## Maybe make a wrapper around nsenter?
          # request_edit_command = "tmux split-window -v nvim {file}";
        }
        // cfg.config
      );

      home.packages =
        let
          pwnproxy = inputs.pwnproxy.packages."${pkgs.stdenv.hostPlatform.system}".default;
          autorize = inputs.autorize.packages."${pkgs.stdenv.hostPlatform.system}".default;
          urlenc = inputs.nvim-http-client.packages."${pkgs.stdenv.hostPlatform.system}".urlenc;
        in
        [
          (mkSandbox {
            name = "pwnproxy";
            prog = "${pwnproxy}/bin/mitmproxy";
            shareCwd = true;
            sharedPaths = [
              {
                hostPath = "$HOME/.mitmproxy";
                boxPath = "/home/sprrw/.mitmproxy";
                ro = false;
                type = "dir";
              }
            ];
            network = true;
            wayland = true; # nvim copy
          })
          urlenc
          (mkSandbox {
            name = "autorize";
            prog = "${autorize}/bin/autorize";
            shareCwd = true;
            network = true;
          })
        ];
    };
}
