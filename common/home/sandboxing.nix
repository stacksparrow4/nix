{ lib, config, ... }:

{
  options.sprrw.sandboxing.enable = lib.mkEnableOption "sandboxing";

  config = lib.mkIf config.sprrw.sandboxing.enable {

  };
}
