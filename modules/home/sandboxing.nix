{ moduleWithSystem, ... }:

{
  flake.modules.homeManager.sandbox = moduleWithSystem (
    { self', ... }:
    { ... }:
    {
      home.packages = with self'.packages; [
        box
        build-vm
      ];

      sprrw.term.shellExtra = ''
        alias b='box'
        alias bc='box --cwd'
      '';
    }
  );
}
