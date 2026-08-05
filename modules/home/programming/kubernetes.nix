{
  flake.homeModules.programming-kubernetes =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        kubectl
        kubernetes-helm
      ];
    };
}
