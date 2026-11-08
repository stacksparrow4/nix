{
  flake.modules.nixos.users =
    { pkgs, ... }:
    {
      programs.zsh.enable = true;
      environment.pathsToLink = [ "/share/zsh" ];

      security.sudo.wheelNeedsPassword = false;

      nix.settings.trusted-users = [
        "@wheel"
      ];

      users.users.sprrw = {
        isNormalUser = true;
        description = "sprrw";
        shell = pkgs.zsh;
        extraGroups = [
          "networkmanager"
          "wheel"
          "podman"
        ];
      };
    };
}
