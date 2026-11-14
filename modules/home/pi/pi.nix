{ moduleWithSystem, ... }:

{
  flake.modules.homeManager.pi = moduleWithSystem (
    { self', ... }:
    {
      pkgs,
      config,
      lib,
      ...
    }:
    let
      cfg = config.sprrw.ai.pi;
    in
    {
      options.sprrw.ai.pi = {
        models = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { providers = {}; };
        };
      };

      config = {
        home.file.".pi/agent/models.json".text = builtins.toJSON cfg.models;
        home.file.".pi/agent/settings.json".source = ./pi-settings.json;

        systemd.user = lib.mkIf pkgs.stdenv.isLinux {
          services.pi-clean-sessions = {
            Unit.Description = "Clear pi session logs older than 1 week";
            Service = {
              Type = "oneshot";
              ExecStart = "${pkgs.findutils}/bin/find ${config.home.homeDirectory}/.pi/agent/sessions -mindepth 1 ( ! -type d -mtime +7 -o -type d -empty ) -delete";
            };
          };

          timers.pi-clean-sessions = {
            Unit.Description = "Clear pi session logs older than 1 week";
            Timer = {
              OnCalendar = "daily";
              Persistent = true;
            };
            Install.WantedBy = [ "timers.target" ];
          };
        };

        home.packages = [
          self'.packages.pi
          self'.packages.pi-exec
        ];
      };
    }
  );
}
