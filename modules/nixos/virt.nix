{
  flake.nixosModules.virt =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        slirp4netns
        podman-compose
      ];

      virtualisation = {
        containers = {
          enable = true;
          containersConf.settings = {
            network.default_rootless_network_cmd = "slirp4netns";
            engine.compose_warning_logs = false;
          };
          registries.search = [ "docker.io" ];
        };
        podman = {
          enable = true;
          dockerCompat = true;
          defaultNetwork.settings.dns_enabled = true;
        };
      };
    };

  flake.nixosModules.workstation-virt = {
    hardware.nvidia-container-toolkit.enable = true;

    programs.virt-manager.enable = true;
    users.groups.libvirtd.members = [ "sprrw" ];
    virtualisation.libvirtd.enable = true;
    virtualisation.spiceUSBRedirection.enable = true;
  };
}
