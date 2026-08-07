{
  perSystem =
    {
      pkgs,
      lib,
      config,
      mkSandbox,
      ...
    }:
    {
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        smuggler = mkSandbox {
          name = "smuggler";
          sharedPaths = [
            {
              hostPath = "$(pwd)/payloads";
              boxPath = "/payloads";
              ro = false;
              type = "dir";
            }
          ];
          network = true;
          prog = "${config.packages.smuggler-unwrapped}/bin/smuggler";
        };
      };
    };
}
