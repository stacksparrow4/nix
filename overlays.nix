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
      "pi-coding-agent"
      "brave-search-cli"
      "lmms-full"
      "signal-desktop"
    ]
)
// {
  interactsh = import ./pkgs/interactsh { pkgs = pkgsUnstable; };

  # Fix for Vesktop screen share: can remove when patch lands upstream
  xdg-desktop-portal-wlr = prev.xdg-desktop-portal-wlr.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      (prev.fetchpatch {
        url = "https://github.com/emersion/xdg-desktop-portal-wlr/commit/c613a8bc7cfbcf5615b59906e247b30b190c8662.patch";
        hash = "sha256-JgxCK6ItToU7UXoLP84JFtsXQDjDErz6Ri4VNpxtMOM=";
      })
    ];
  });
}
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
// {
  # Security patch
  vimPlugins = prev.vimPlugins // {
    typst-preview-nvim = pkgsUnstable.vimPlugins.typst-preview-nvim;
  };
}
