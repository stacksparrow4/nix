{
  inputs,
  config,
  withSystem,
  moduleWithSystem,
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
        (moduleWithSystem (
          { self', ... }:
          { pkgs, config, ... }:
          {
            imports = with homeModules; [
              base
              general
              nvim
              sandbox

              ai-pi

              term-aliases
              term-bash
              term-zshrc
              term-yazi
              term-tmux

              programming-git
              programming-rust
            ];

            sprrw = {
              term.tmux.defaultTerm = "xterm-ghostty";
              # https://aistudio.google.com/app/api-keys
              ai.pi.execModel = "gemini-3.6-flash";
            };

            home = {
              username = "dan";
              homeDirectory = "/Users/dan";
            };

            # Ghostty settings I'm not sure I need
            #
            # app-notifications = no-clipboard-copy
            # env = TERMINFO_DIRS=/Users/dan/.terminfo

            home.file."Library/Application Support/com.mitchellh.ghostty/config".text = ''
              command = ${pkgs.tmux}/bin/tmux
              macos-option-as-alt = true
            '';

            home.file.".terminfo".source =
              config.lib.file.mkOutOfStoreSymlink "/Applications/Ghostty.app/Contents/Resources/terminfo";

            home.packages =
              with pkgs;
              [
                sshpass
                shtris
              ]
              ++ (with self'.packages; [
                start-linux-builder
                sprrw
              ]);

            home.sessionVariables = {
              NIX_PATH = "nixpkgs=${inputs.nixpkgs}:nixpkgs-unstable=${inputs.nixpkgs-unstable}";
            };
          }
        ))
      ];
    }
  );
}
