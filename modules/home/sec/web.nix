{ moduleWithSystem, ... }:

{
  flake.homeModules.sec-web = moduleWithSystem (
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
