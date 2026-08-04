{
  pkgs-unstable,
}:

let
  pkgs = pkgs-unstable;

  version = "0.83.0";

  src = pkgs.fetchFromGitHub {
    owner = "earendil-works";
    repo = "pi";
    rev = "v${version}";
    hash = "sha256-+XRJua2TSXkZMnWtxtLMskSzEHrGEFFyvYcPATi7An4=";
  };

  piAiTarball = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${version}.tgz";
    hash = "sha256-+YPCiiEgkwXtnCdJd+KRMPpNiEjfbN836QlNlcx7xtQ=";
  };
in
pkgs.pi-coding-agent.overrideAttrs {
  inherit version src;
  npmDeps = pkgs.fetchNpmDeps {
    name = "pi-mono-${version}-npm-deps";
    inherit src;
    hash = "sha256-AbSfP1Ion8bN309NUBQb1QSn2cIIUjNONmZgls9vnYE=";
  };

  modelData = piAiTarball;
}
