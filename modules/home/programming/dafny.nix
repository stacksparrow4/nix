{
  flake.homeModules.programming-dafny =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        dafny
      ];
    };
}
