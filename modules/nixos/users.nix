{
  flake.nixosModules.users = {
    security.sudo.wheelNeedsPassword = false;

    nix.settings.trusted-users = [
      "root"
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
