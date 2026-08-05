{ moduleWithSystem, ... }:

{
  flake.homeModules.sec-snmp = moduleWithSystem (
    { self', ... }:
    { ... }:
    {
      home.packages = with self'.packages; [
        snmpwalk
        snmpcheck
      ];
    }
  );
}
