{ moduleWithSystem, ... }:

{
  flake.modules.homeManager.web = moduleWithSystem (
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
