{
  flake.modules.homeManager.kubernetes =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        kubectl
        kubernetes-helm
      ];
    };
}
