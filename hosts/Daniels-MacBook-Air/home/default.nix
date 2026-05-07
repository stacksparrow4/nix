{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  imports = [
    ../../../common/home
  ];

  home = {
    username = "dan";
    homeDirectory = "/Users/dan";
  };

  programs.ghostty = {
    enable = true;
    package = null;
    settings = {
      env = "TERMINFO_DIRS=/Users/dan/.terminfo";
      command = lib.mkForce "${pkgs.tmux}/bin/tmux";
      app-notifications = "no-clipboard-copy";
    };
  };

  home.file.".terminfo" = {
    source = config.lib.file.mkOutOfStoreSymlink "/Applications/Ghostty.app/Contents/Resources/terminfo";
  };

  home.packages = with pkgs; [
    sshpass
    # (pkgs.writeShellApplication {
    #   name = "connect";
    #   text = ''
    #     sshpass -p password ssh -o PreferredAuthentications=password -R /run/user/1000/1p-agent.sock:/Users/dan/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock -t sprrw@192.168.65.2 'export SSH_AUTH_SOCK=/run/user/1000/1p-agent.sock; exec tmux'
    #   '';
    # })

    # TODO: set up docker builder so this works
    # then override the pi-coding-agent
    #(
      #import ../../../pkgs/pi { pkgs = import pkgs-unstable { system = "aarch64-linux"; }; }
    #)
  ];

  home.sessionVariables = {
    NIX_PATH = "nixpkgs=${inputs.nixpkgs}:nixpkgs-unstable=${inputs.nixpkgs-unstable}";
  };

  sprrw = {
    nvim = {
      enable = true;
      sandboxed = false;
    };
    term = {
      zshrc.enable = true;
      yazi.enable = true;
      tmux = {
        enable = true;
        defaultTerm = "ghostty";
      };
      ghostty = {
        font = {
          family = "IosevkaTerm Nerd Font Mono";
          size = 14;
        };

        installTerminfo = false;

        # bindings = [
        #   { key = "Right"; mods = "Alt"; chars = "\\u001BF"; }
        #   { key = "Left";  mods = "Alt"; chars = "\\u001BB"; }
        #   { key = "Left";  mods = "Command"; chars = "\\u0001"; }
        #   { key = "Right"; mods = "Command"; chars = "\\u0005"; }
        # ];
      };
    };
  };

  # Fix for apps not showing up in spotlight search
  # home.activation = {
  #   rsync-home-manager-applications = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  #     rsyncArgs="--archive --checksum --chmod=-w --copy-unsafe-links --delete"
  #     apps_source="$genProfilePath/home-path/Applications"
  #     moniker="Home Manager Trampolines"
  #     app_target_base="${config.home.homeDirectory}/Applications"
  #     app_target="$app_target_base/$moniker"
  #     mkdir -p "$app_target"
  #     ${pkgs.rsync}/bin/rsync $rsyncArgs "$apps_source/" "$app_target"
  #   '';
  # };
}
