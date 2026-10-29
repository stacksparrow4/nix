{
  flake.modules.nixos.users = {
    security.sudo.wheelNeedsPassword = false;

    nix.settings.trusted-users = [
      "@wheel"
    ];

    users.users.sprrw = {
      isNormalUser = true;
      description = "sprrw";
      extraGroups = [
        "networkmanager"
        "wheel"
        "podman"
      ];
    };
  };
}
