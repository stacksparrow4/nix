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
      (
        let
          dockerFileDir = pkgs.writeTextDir "Dockerfile" ''
            FROM ubuntu:latest

            RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y wget && \
              wget -O /usr/bin/jtool2 https://github.com/excitedplus1s/jtool2/raw/refs/heads/main/jtool2.ELF64 && \
              chmod +x /usr/bin/jtool2
          '';
        in
        pkgs.writeShellScriptBin "jtool2" ''
          set -e

          if ! docker inspect jtool2 &>/dev/null; then
            docker build -t jtool2 ${dockerFileDir}
          fi

          docker run --rm -it -u 1000:100 -v $(pwd):/pwd -w /pwd jtool2 jtool2 "$@"
        ''
      )
      (
        let
          disarmSrc = fetchTarball {
            url = "https://newosxbook.com/tools/disarm.tgz";
            sha256 = "sha256:0685db56yqr9mdqdxkv1ai7g8yvqz8s58cz71ql2xfdc96pnxbbf";
          };
        in
        pkgs.writeShellScriptBin "disarm" ''
          set -e

          docker run --rm -it -u 1000:100 -v $(pwd):/pwd -v ${disarmSrc}:${disarmSrc}:ro -w /pwd ubuntu:latest ${disarmSrc}/binaries/disarm.linux.x86_64 "$@"
        ''
      )
    ];
  };
}
