{ config, lib, pkgs, ... }:

{
  options = {
    sprrw.sec.mobile.enable = lib.mkEnableOption "mobile";
  };

  config = lib.mkIf config.sprrw.sec.mobile.enable {
    home.packages = with pkgs; [
      frida-tools
      apktool
      jadx
      android-tools
      (
        buildGoModule (finalAttrs: {
          name = "ipsw";

          src = fetchFromGitHub {
            owner = "blacktop";
            repo = "ipsw";
            rev = "505147c79000f05bdf1264f85551ea72dda2a20e";
            hash = "sha256-DrtOMJxbUFt27Ct7IsrpdR5JhBImkYAQ/A54DSTV6T0=";
          };

          subPackages = [ "cmd/ipsw" ];

          vendorHash = "sha256-Nve5kOxeeV1rp3ghtPK3/E3tGdzmMDW7t0CCwPyTjiY=";
        })
      )
    ];
  };
}
