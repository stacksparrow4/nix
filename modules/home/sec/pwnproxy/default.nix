{ moduleWithSystem, ... }:

{
  flake.homeModules.sec-pwnproxy = moduleWithSystem (
    { self', ... }:
    { config, lib, ... }:
    {
      options.sprrw.sec.pwnproxy.config = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Extra keys merged into ~/.config/pwnproxy/config.json.";
      };

      config = {
        home.file.".config/pwnproxy/tools".source = ./tools;
        home.file.".config/pwnproxy/config.json".text = builtins.toJSON config.sprrw.sec.pwnproxy.config;

        home.packages = [
          self'.packages.pwnproxy
          self'.packages.urlenc
          self'.packages.autorize
        ];
      };
    }
  );
}
