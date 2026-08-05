{
  inputs,
  config,
  withSystem,
  ...
}:

let
  homeModules = config.flake.homeModules;
in
{
  flake.homeConfigurations.dan = withSystem "aarch64-darwin" (
    { pkgs, ... }:
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        {
          # No Linux aspects and no sandboxed tools: the sandbox helper is
          # bubblewrap-based.
          imports = with homeModules; [
            base
            general
            scripts
            nvim

            term-zshrc
            term-yazi
            term-tmux

            programming-git
            programming-kubernetes
          ];

          sprrw = {
            nvim.sandboxed = false;
            term.tmux.defaultTerm = "ghostty";
          };
        }

        (
          { pkgs, config, ... }:
          {
            home = {
              username = "dan";
              homeDirectory = "/Users/dan";
            };

            programs.ghostty = {
              enable = true;
              package = null;
              settings = {
                env = "TERMINFO_DIRS=/Users/dan/.terminfo";
                command = "${pkgs.tmux}/bin/tmux";
                app-notifications = "no-clipboard-copy";
                macos-option-as-alt = true;
              };
            };

            home.file.".terminfo".source =
              config.lib.file.mkOutOfStoreSymlink "/Applications/Ghostty.app/Contents/Resources/terminfo";

            home.packages = with pkgs; [
              sshpass
              shtris
              (pkgs.writeShellApplication {
                name = "connect";
                text = ''
                  sshpass -p password ssh root@192.168.64.2
                '';
              })
              (pkgs.writeShellApplication {
                name = "nixvm-rebuild";
                text = ''
                  nix run nixpkgs#nixos-rebuild -- switch \
                    --flake ~/nixos/modules/hosts/_macbook-vm#macbook-vm \
                    --target-host root@192.168.64.2 \
                    --build-host root@192.168.64.2
                '';
              })
            ];

            home.file.".config/nix/nix.conf".text = ''
              experimental-features = nix-command flakes
              builders = ssh://root@192.168.64.2 aarch64-linux
            '';

            # Note: this ssh host has to be valid for the Mac root user
            # sudo launchctl kickstart -k system/org.nixos.nix-daemon

            home.sessionVariables = {
              NIX_PATH = "nixpkgs=${inputs.nixpkgs}:nixpkgs-unstable=${inputs.nixpkgs-unstable}";
            };
          }
        )
      ];
    }
  );
}
