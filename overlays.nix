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
      "brave"
      "pi-coding-agent"
      "signal-desktop"
    ]
)
// {
  interactsh = import ./pkgs/interactsh { pkgs = pkgsUnstable; };
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
