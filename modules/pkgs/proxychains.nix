{
  perSystem =
    {
      pkgs,
      ...
    }:
    {
      packages = {
        proxychains = pkgs.writeShellScriptBin "proxychains" ''
          ${pkgs.proxychains-ng}/bin/proxychains4 -q "$@"
        '';
      };
    };
}
