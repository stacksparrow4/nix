{
  pkgs,
  config,
  lib,
  ...
}:

{
  config = lib.mkMerge [
    {
      # virtualisation.docker.enable = true;
      environment.systemPackages = with pkgs; [ slirp4netns podman-compose ];

      virtualisation = {
        containers = {
          enable = true;
          containersConf.settings = {
            network.default_rootless_network_cmd = "slirp4netns";
            engine.compose_warning_logs = false;
          };
        };
        podman = {
          enable = true;
          dockerCompat = true;
          defaultNetwork.settings.dns_enabled = true;
        };
      };
    }
    (lib.mkIf (!config.sprrw.headless) {
      # services.opensnitch.enable = true;

      hardware.nvidia-container-toolkit.enable = true;

      programs.virt-manager.enable = true;
      users.groups.libvirtd.members = [ "sprrw" ];
      virtualisation.libvirtd.enable = true;
      virtualisation.spiceUSBRedirection.enable = true;
    })
  ];
}
