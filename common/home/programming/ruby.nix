{
  config,
  lib,
  pkgs,
  ...
}:

{
  options = {
    sprrw.programming.ruby.enable = lib.mkEnableOption "ruby";
  };

  config = lib.mkIf config.sprrw.programming.ruby.enable {
    home = {
      packages = with pkgs; [
        ruby
      ];
    };
  };
}
