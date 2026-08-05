{
  config,
  lib,
  pkgs,
  self',
  ...
}:

{
  options = {
    sprrw.sec.snmp.enable = lib.mkEnableOption "snmp";
  };

  config = lib.mkIf config.sprrw.sec.snmp.enable {
    home.packages = (with self'.packages; [
      snmpwalk
      snmpcheck
    ]);
  };
}
