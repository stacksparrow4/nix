{ config, lib, pkgs, ... }:

{
  options = {
    sprrw.sec.snmp.enable = lib.mkEnableOption "snmp";
  };

  config = lib.mkIf config.sprrw.sec.snmp.enable {
    home.packages = with pkgs; [
      (config.sprrw.sandboxing.runDockerBin { name = "snmpwalk"; args = "DOCKERIMG ${net-snmp}/bin/snmpwalk"; })
      (config.sprrw.sandboxing.runDockerBin { name = "snmpcheck"; args = "DOCKERIMG ${snmpcheck}/bin/snmpcheck"; })
    ];
  };
}
