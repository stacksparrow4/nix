{
  config,
  lib,
  self',
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

      home.packages = [
        self'.packages.pwnproxy
        self'.packages.urlenc
        self'.packages.autorize
      ];
    };
}
