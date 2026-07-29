{
  pkgs,
  inputs,
  ...
}:

{
  home.packages = [
    (import ../../pkgs/sprrw {
      inherit pkgs;
      inherit (inputs) crane;
    })
  ];
}
