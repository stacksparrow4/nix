{ moduleWithSystem, ... }:

{
  flake.modules.homeManager.snmp = moduleWithSystem (
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
