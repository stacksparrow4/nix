{
  flake.modules.nixos.tailscale = {
    services.tailscale = {
      enable = true;
      extraSetFlags = [ "--shields-up" ];
    };
  };
}
