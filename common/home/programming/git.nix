{ config, lib, ... }:

{
  options = {
    sprrw.programming.git.enable = lib.mkEnableOption "git";
  };

  config = lib.mkIf config.sprrw.programming.git.enable {
    programs.git = {
      enable = true;
      settings = {
        user = {
          email = "stacksparrow4@gmail.com";
          name = "Daniel Cooper";
        };
        safe.bareRepository = "explicit";
      };
    };
  };
}
