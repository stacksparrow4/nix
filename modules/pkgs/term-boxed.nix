# Terminal tooling wrappers (Linux).
{
  perSystem =
    {
      pkgs,
      lib,
      mkSandbox,
      ...
    }:
    {
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        neofetch = mkSandbox {
          name = "neofetch";
          prog = "${pkgs.fastfetch}/bin/fastfetch";
        };

        proxychains = pkgs.writeShellScriptBin "proxychains" ''
          ${pkgs.proxychains-ng}/bin/proxychains4 -q "$@"
        '';
      };
    };
}
