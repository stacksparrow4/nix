pkgsUnstable: final: prev:

# Note that it is generally considered bad practice to use overlays to update packages.
# However as long as I don't upgrade dependencies this way its usually fine
builtins.listToAttrs (
  map
    (name: {
      inherit name;
      value = pkgsUnstable."${name}";
    })
    [
      # List of unstable packages
      "_1password-gui"
      "_1password-cli"
      "slack"
      "ropr" # Doesnt exist on stable
      "brave"
      "claude-code"
      "qwen-code"
      "pi-coding-agent"
      "brave-search-cli"
    ]
)
// (
  let
    asepritePkgs =
      import
        (fetchTarball {
          url = "https://github.com/NixOS/nixpkgs/archive/4e92bbcdb030f3b4782be4751dc08e6b6cb6ccf2.tar.gz";
          sha256 = "sha256:1mrf745k78ivw11rj1qibgwi966a83lcljc62p4qix25m1ignirq";
        })
        {
          system = pkgsUnstable.stdenv.hostPlatform.system;
          config = import ./nixpkgs-config.nix;
        };
  in
  {
    aseprite = asepritePkgs.aseprite;
  }
)
// (
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
)
// {
  # Security patch
  vimPlugins = prev.vimPlugins // {
    typst-preview-nvim = pkgsUnstable.vimPlugins.typst-preview-nvim;
  };
}
