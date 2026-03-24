{ config, lib, ... }:

{
  config = lib.mkMerge [
    {
      virtualisation.docker.enable = true;
    }
    (lib.mkIf (!config.sprrw.headless) {
      hardware.nvidia-container-toolkit.enable = true;

      programs.virt-manager.enable = true;
      users.groups.libvirtd.members = ["sprrw"];
      virtualisation.libvirtd.enable = true;
      virtualisation.spiceUSBRedirection.enable = true;
    })
  ];
}
