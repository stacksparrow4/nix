pkgsUnstable:
final: prev:

builtins.listToAttrs (
  map (name: {
    inherit name;
    value = pkgsUnstable."${name}";
  }) [
    # List of unstable packages
    "brave"
    "_1password-gui"
    "_1password-cli"
    "slack"
    "discord"
    "ropr" # Doesnt exist on stable
  ]
) // (
  # Qemu breaks VMs so pin it to an exact version
  # TODO: does this actually work :/
  # Might need to set programs.virt-manager.package or something like that for each of them
  let
    qemu-nixpkgs = import (fetchTarball {
      url = "https://github.com/NixOS/nixpkgs/archive/c2ae88e026f9525daf89587f3cbee584b92b6134.tar.gz";
      sha256 = "sha256:1fsnvjvg7z2nvs876ig43f8z6cbhhma72cbxczs30ld0cqgy5dks";
    }) { system = pkgsUnstable.stdenv.hostPlatform.system; };
  in
  {
    libvirt = qemu-nixpkgs.libvirt;
    qemu = qemu-nixpkgs.qemu;
    virt-manager = qemu-nixpkgs.virt-manager;
  }
) // {
  # Security patch
  vimPlugins = prev.vimPlugins // {
    typst-preview-nvim = pkgsUnstable.vimPlugins.typst-preview-nvim;
  };
}
