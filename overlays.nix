pkgsStable: # note first line is removed in environments/default.nix, do not change
final: prev:
{
  flameshot = pkgsStable.flameshot;
  cmake-language-server = pkgsStable.cmake-language-server;
  sage = pkgsStable.sage;
  mitmproxy = pkgsStable.mitmproxy;

  pywithi3ipc = pkgsStable.python312.withPackages (ppkgs: [
      ppkgs.i3ipc
  ]);
}
