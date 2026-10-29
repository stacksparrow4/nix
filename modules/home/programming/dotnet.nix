{
  flake.modules.homeManager.dotnet =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        dotnet-sdk
        roslyn-ls
      ];
    };
}
