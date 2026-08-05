{
  flake.homeModules.programming-java =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        openjdk
        jdt-language-server
      ];
    };
}
