{
  flake.nixosModules.tailscale = {
    services.tailscale = {
      enable = true;
      extraSetFlags = [ "--shields-up" ];
    };
  };
}
