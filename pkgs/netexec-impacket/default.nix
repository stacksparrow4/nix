{
  nixpkgs-inputs ? { },
  pkgs ? import <nixpkgs> nixpkgs-inputs,
}:

pkgs.python313Packages.impacket.overridePythonAttrs {
  version = "dev";
  src = pkgs.fetchFromGitHub {
    owner = "Pennyw0rth";
    repo = "impacket";
    rev = "1049826efbc556221cca17f94e9fd0b944b8c600";
    hash = "sha256-FrWGtDPDkXoFrSiPlfyvExXiyQOAERlR0nQE2pQODPY=";
  };
  postPatch = ''
    substituteInPlace setup.py \
      --replace 'version="{}.{}.{}.{}{}"' 'version="{}.{}.{}"'
  '';
  passthru.updateScript = ./update.sh;
}
