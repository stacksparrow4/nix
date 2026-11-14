{
  flake.modules.nixos.podman =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        slirp4netns
        podman-compose
      ];

      virtualisation = {
        containers = {
          containersConf.settings = {
            network.default_rootless_network_cmd = "slirp4netns";
            engine.compose_warning_logs = false;
            engine.detach_keys = "";
          };
          registries.search = [ "docker.io" ];
        };
        podman = {
          enable = true;
          dockerCompat = true;
          defaultNetwork.settings.dns_enabled = true;
        };
      };
    };
}
