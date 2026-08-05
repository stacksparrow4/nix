{
  lib,
  config,
  ...
}:

{
  options.sprrw.term.yazi.enable = lib.mkEnableOption "yazi";

  config = lib.mkIf config.sprrw.term.yazi.enable {
    programs.yazi = {
      enable = true;
      shellWrapperName = "y";

      keymap = {
        mgr.prepend_keymap = [
          {
            run = "quit";
            on = [ "<Esc>" ];
          }
          {
            run = "remove --permanently";
            on = [ "d" ];
          }
        ];

        spot.prepend_keymap = [{
          on = "q";
          run = "close";
        }];
      };
    };
  };
}
