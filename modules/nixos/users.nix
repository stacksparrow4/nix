{
  flake.modules.nixos.users =
    { config, ... }:
    let
      zsh = "${config.home-manager.users.sprrw.home.profileDirectory}/bin/zsh";
    in
    {
      programs.zsh.enable = true;
      programs.zsh.enableGlobalCompInit = false;
      environment.pathsToLink = [ "/share/zsh" ];
      environment.shells = [ zsh ];

      security.sudo.wheelNeedsPassword = false;

      nix.settings.trusted-users = [
        "@wheel"
      ];

      users.users.sprrw = {
        isNormalUser = true;
        description = "sprrw";
        shell = zsh;
        extraGroups = [
          "networkmanager"
          "wheel"
          "podman"
        ];
      };
    };
}
