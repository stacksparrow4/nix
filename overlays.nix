pkgsStable: # note first line is removed in environments/default.nix, do not change
final: prev:
{
  cmake-language-server = pkgsStable.cmake-language-server;
  mitmproxy = pkgsStable.mitmproxy;

  ltrace = pkgsStable.ltrace;

  libreoffice = pkgsStable.libreoffice;

  sage = pkgsStable.sage;
}
