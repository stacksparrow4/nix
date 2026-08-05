{
  flake.homeModules.programming-dotnet =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        dotnet-sdk
        roslyn-ls
      ];
    };
}
