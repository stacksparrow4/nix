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
    "ollama-cuda"
    "ropr" # Doesnt exist on stable
  ]
) // (
  let
    manPatch = import (fetchTarball {
      url = "https://github.com/NixOS/nixpkgs/archive/fa83fd837f3098e3e678e6cf017b2b36102c7211.tar.gz";
      sha256 = "sha256:1jig9kwjd52brwfm6n4pipqn1qfjlpasjhfsb8di70cb87z4xdbv";
    }) { system = pkgsUnstable.stdenv.hostPlatform.system; };
  in {
    linux-manual = manPatch.linux-manual;
    inetutils = manPatch.inetutils;
  }
) // (
  # Qemu breaks VMs so pin it to an exact version
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

  # Flameshot is buggy in new versions
  flameshot = (import (fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/aefcb0d50d1124314429a11ed6b7aaaedf2861c5.tar.gz";
    sha256 = "sha256:0bsn2j5p8vf42fydf252mqhg5wfh7907wdjinzajz6pknkqdylnf";
  }) { system = pkgsUnstable.stdenv.hostPlatform.system; }).flameshot;
}
