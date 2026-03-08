{ config, lib, pkgs, ... }:

{
  options = {
    sprrw.sec.snmp.enable = lib.mkEnableOption "snmp";
  };

  config = lib.mkIf config.sprrw.sec.snmp.enable {
    home.packages = with pkgs; [
      (config.sprrw.sandboxing.runDockerBin { binName = "snmpwalk"; beforeTargetArgs = ""; afterTargetArgs = "${net-snmp}/bin/snmpwalk"; })
      (config.sprrw.sandboxing.runDockerBin { binName = "snmpcheck"; beforeTargetArgs = ""; afterTargetArgs = "${snmpcheck}/bin/snmpcheck"; })
    ];
  };
}
