{ config, lib, pkgs, ... }:

{
  options = {
    sprrw.sec.snmp.enable = lib.mkEnableOption "snmp";
  };

  config = lib.mkIf config.sprrw.sec.snmp.enable {
    home.packages = with pkgs; [ net-snmp snmpcheck ];
  };
}
