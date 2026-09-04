{
  perSystem =
    { pkgs, ... }:
    {
      packages.python = pkgs.python3.withPackages (pypkgs: with pypkgs; [ requests ]);
    };
}
