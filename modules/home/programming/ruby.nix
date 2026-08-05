{
  flake.homeModules.programming-ruby =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        ruby
      ];
    };
}
