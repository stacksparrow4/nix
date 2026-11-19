{
  flake.modules.homeManager.rocq =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        (coqPackages.coq.withPackages (p: [ p.stdlib ]))
      ];
    };
}
