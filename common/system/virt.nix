{
  virtualisation.docker.enable = true;

  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = ["sprrw"];
  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;
}
