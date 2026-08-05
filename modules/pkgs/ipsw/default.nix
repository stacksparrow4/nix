{
  perSystem =
    { pkgs, ... }:
    {
      packages.ipsw = pkgs.buildGoModule (finalAttrs: {
        name = "ipsw";

        src = pkgs.fetchFromGitHub {
          owner = "blacktop";
          repo = "ipsw";
          rev = "505147c79000f05bdf1264f85551ea72dda2a20e";
          hash = "sha256-DrtOMJxbUFt27Ct7IsrpdR5JhBImkYAQ/A54DSTV6T0=";
        };

        subPackages = [ "cmd/ipsw" ];

        vendorHash = "sha256-Nve5kOxeeV1rp3ghtPK3/E3tGdzmMDW7t0CCwPyTjiY=";
      });
    };
}
