{ pkgs, ... }:

{
  virtualisation.docker.enable = true;

  # Don't update qemu because it breaks VMs
  nixpkgs.overlays = let
    qemu-nixpkgs = import (fetchTarball {
      url = "https://github.com/NixOS/nixpkgs/archive/c2ae88e026f9525daf89587f3cbee584b92b6134.tar.gz";
      sha256 = "sha256:1fsnvjvg7z2nvs876ig43f8z6cbhhma72cbxczs30ld0cqgy5dks";
    }) { system = pkgs.system; };
  in
  [
    (final: prev: {
      libvirt = qemu-nixpkgs.libvirt;
      qemu = qemu-nixpkgs.qemu;
      virt-manager = qemu-nixpkgs.virt-manager;
    })
  ];
  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = ["sprrw"];
  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;
}
