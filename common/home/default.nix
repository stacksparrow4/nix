{ lib, ... }:

{
  imports = [
    ./alacritty.nix
    ./bash.nix
    ./burp.nix
    ./environments
    ./git.nix
    ./i3.nix
    ./navi.nix
    ./nvim.nix
    ./packages.nix
    ./rofi.nix
    ./scripts
    ./slack.nix
    ./tmux.nix
    ./zshrc.nix
    ({ config, ...}:
    {
      home.file = lib.mkIf config.sprrw.sshConfig {
        ".ssh/config".text = builtins.readFile ./dotfiles/ssh/config;
      };
    })
  ];

  options.sprrw = {
    macosMode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable patches/settings specific to MacOS";
    };

    sshConfig = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = {
    # This value determines the Home Manager release that your configuration is
    # compatible with. This helps avoid breakage when a new Home Manager release
    # introduces backwards incompatible changes.
    #
    # You should not change this value, even if you update Home Manager. If you do
    # want to update the value, then make sure to first check the Home Manager
    # release notes.
    home.stateVersion = "24.11"; # Please read the comment before changing.

    # Home Manager is pretty good at managing dotfiles. The primary way to manage
    # plain files is through 'home.file'.
    home.file.".config/nixpkgs/config.nix".text = ''
      { allowUnfree = true; }
    '';


    # Home Manager can also manage your environment variables through
    # 'home.sessionVariables'. These will be explicitly sourced when using a
    # shell provided by Home Manager. If you don't want to manage your shell
    # through Home Manager then you have to manually source 'hm-session-vars.sh'
    # located at either
    #
    #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
    #
    # or
    #
    #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
    #
    # or
    #
    #  /etc/profiles/per-user/sprrw/etc/profile.d/hm-session-vars.sh
    #
    home.sessionVariables = {
      # EDITOR = "emacs";
    };

    # Let Home Manager install and manage itself.
    programs.home-manager.enable = true;
  };
}
