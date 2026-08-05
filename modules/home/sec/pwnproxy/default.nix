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
        home.file.".config/pwnproxy/config.json".text = builtins.toJSON (
          {
            ## TODO: figure out a safe way of using tmux while being sandboxed
            ## Maybe make a wrapper around nsenter?
            # request_edit_command = "tmux split-window -v nvim {file}";
          }
          // config.sprrw.sec.pwnproxy.config
        );

        home.packages = [
          self'.packages.pwnproxy
          self'.packages.urlenc
          self'.packages.autorize
        ];
      };
    }
  );
}
