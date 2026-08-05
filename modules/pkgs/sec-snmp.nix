{
  perSystem =
    {
      pkgs,
      lib,
      mkSandbox,
      ...
    }:
    {
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        snmpwalk = mkSandbox {
          name = "snmpwalk";
          network = true;
          prog = "${pkgs.net-snmp}/bin/snmpwalk";
        };

        snmpcheck = mkSandbox {
          name = "snmpcheck";
          network = true;
          prog = "${pkgs.snmpcheck}/bin/snmpcheck";
        };
      };
    };
}
