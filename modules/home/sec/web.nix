{ moduleWithSystem, ... }:

{
  flake.homeModules.web = moduleWithSystem (
    { self', ... }:
    { ... }:
    {
      home.packages = with self'.packages; [
        mitmproxy
        interactsh
        oob
      ];
    }
  );
}
