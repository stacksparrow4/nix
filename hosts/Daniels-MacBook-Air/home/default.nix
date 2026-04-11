{
  pkgs,
  lib,
  config,
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

  programs.ghostty.package = null;
  home.file.".terminfo" = {
    source = config.lib.file.mkOutOfStoreSymlink "/Applications/Ghostty.app/Contents/Resources/terminfo";
  };
  programs.ghostty.settings.env = "TERMINFO_DIRS=/Users/dan/.terminfo";
  programs.ghostty.settings.command = lib.mkForce "zsh";

  home.packages = with pkgs; [ neovim sshpass (
    pkgs.writeShellApplication {
      name = "connect";
      text = ''
        sshpass -p password ssh -o PreferredAuthentications=password -R /run/user/1000/1p-agent.sock:/Users/dan/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock -t sprrw@192.168.65.2 'export SSH_AUTH_SOCK=/run/user/1000/1p-agent.sock; exec tmux'
      '';
    }
  )];

  sprrw = {
    term = {
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
