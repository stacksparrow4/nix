{
  flake.homeModules.ruby =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        ruby
      ];
    };
}
