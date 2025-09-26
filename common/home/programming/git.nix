{ config, lib, ... }:

{
  options = {
    sprrw.programming.git.enable = lib.mkEnableOption "git";
  };

  config = lib.mkIf config.sprrw.programming.git.enable {
    programs.git = {
      enable = true;
      userEmail = "stacksparrow4@gmail.com";
      userName = "Daniel Cooper";
      extraConfig.safe.bareRepository = "explicit";
    };
  };
}
