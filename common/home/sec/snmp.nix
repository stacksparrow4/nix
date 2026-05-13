{
  config,
  lib,
  pkgs,
  mkSandbox,
  ...
}:

{
  options = {
    sprrw.sec.snmp.enable = lib.mkEnableOption "snmp";
  };

  config = lib.mkIf config.sprrw.sec.snmp.enable {
    home.packages = with pkgs; [
      (mkSandbox {
        name = "snmpwalk";
        network = true;
        prog = "${net-snmp}/bin/snmpwalk";
      })
      (mkSandbox {
        name = "snmpcheck";
        network = true;
        prog = "${snmpcheck}/bin/snmpcheck";
      })
    ];
  };
}
