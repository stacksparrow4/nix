{
  flake.homeModules.dafny =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        dafny
      ];
    };
}
