{ moduleWithSystem, ... }:

{
  flake.homeModules.sec-web = moduleWithSystem (
    { self', ... }:
    { ... }:
    {
      home.packages = with self'.packages; [
        mitmproxy
        interactsh-boxed
        oob-boxed
      ];
    }
  );
}
