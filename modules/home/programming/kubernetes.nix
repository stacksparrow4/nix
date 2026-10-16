{
  flake.homeModules.kubernetes =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        kubectl
        kubernetes-helm
      ];
    };
}
