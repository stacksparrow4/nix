{ moduleWithSystem, ... }:

{
  flake.homeModules.snmp = moduleWithSystem (
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
