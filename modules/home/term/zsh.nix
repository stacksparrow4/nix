{ moduleWithSystem, ... }:

{
  flake.modules.homeManager.zsh = moduleWithSystem (
    { self', ... }:
    { config, lib, ... }:
    {
      options.sprrw.term.zsh.prompt = lib.mkOption {
        type = lib.types.str;
        default = "\n%B%F{cyan} %1~ %(!.#.$)%f%b ";
      };

      config.home.packages = [
        (self'.packages.zsh.override {
          prompt = config.sprrw.term.zsh.prompt;
          shellExtra = config.sprrw.term.shellExtra;
          sessionVariablesPackage = config.home.sessionVariablesPackage;
        })
      ];
    }
  );
}
