{
  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        proxychains = pkgs.writeShellScriptBin "proxychains" ''
          ${pkgs.proxychains-ng}/bin/proxychains4 -q "$@"
        '';
      };
    };
}
