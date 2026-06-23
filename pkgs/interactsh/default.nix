{
  pkgs,
}:

pkgs.buildGoModule (finalAttrs: {
  pname = "interactsh";
  version = "1.3.1-dev";

  src = pkgs.fetchFromGitHub {
    owner = "projectdiscovery";
    repo = "interactsh";
    rev = "9c9b482e6ddfa6e02316972a9da51cc4773e7f60";
    hash = "sha256-KaJJlIldqX31cyVf67JEZrzsf1oAuxpfh6WHQka4uiE=";
  };

  vendorHash = "sha256-prpcUG525Z0wui7SO6pOOxya1FmgnXhzRGkGwD44MEo=";

  modRoot = ".";
  subPackages = [
    "cmd/interactsh-client"
    "cmd/interactsh-server"
  ];

  doCheck = false;
})
