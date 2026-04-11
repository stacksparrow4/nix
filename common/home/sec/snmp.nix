{
  config,
  lib,
  pkgs,
  ...
}:

{
  options = {
    sprrw.sec.snmp.enable = lib.mkEnableOption "snmp";
  };

  config = lib.mkIf config.sprrw.sec.snmp.enable {
    home.packages = with pkgs; [
      (config.sprrw.sandbox.create {
        name = "snmpwalk";
        network = true;
        prog = "${net-snmp}/bin/snmpwalk";
      })
      (config.sprrw.sandbox.create {
        name = "snmpcheck";
        network = true;
        prog = "${snmpcheck}/bin/snmpcheck";
      })
    ];
  };
}
