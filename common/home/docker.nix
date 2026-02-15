{ config, lib, ... }:

{
  options.sprrw.docker-config = {
    enable = lib.mkEnableOption "docker-config";
  };

  config = let
    cfg = config.sprrw.docker-config;
  in lib.mkIf cfg.enable {
    home.file.".docker/config.json".text = ''
      {
        "detachKeys": "ctrl-z,z"
      }
    '';
  };
}
