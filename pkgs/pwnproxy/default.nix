{
  nixpkgs-inputs ? { },
  pkgs ? import <nixpkgs> nixpkgs-inputs,
}:

pkgs.mitmproxy.overrideAttrs (
  finalAttrs: prevAttrs: {
    pname = "pwnproxy";
    version = "0.1.0";
    src = pkgs.fetchFromGitHub {
      owner = "stacksparrow4";
      repo = "pwnproxy";
      rev = "90bccccddded743bd188d785944cfe8aeaee79d1";
      hash = "sha256-klb0W15EiZKPtcTI2IkgLsJaxpbUP4oDiGFsRlAevDg=";
    };
  }
)
