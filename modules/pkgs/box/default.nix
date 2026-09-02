{
  perSystem =
    {
      pkgs,
      lib,
      pkgsLinux,
      ...
    }:
    {
      packages = {
        box =
          let
            rustBin = (import ./_Cargo.nix { inherit pkgs; }).rootCrate.build;
            terminfo =
              if pkgs.stdenv.hostPlatform.isLinux then
                "${pkgs.foot.terminfo}/share/terminfo"
              else
                "${pkgsLinux.ghostty.terminfo}/share/terminfo";
            bin = pkgs.runCommand "box-bin" { } ''
              mkdir $out
              ln -s ${pkgs.bash}/bin/sh $out/sh
            '';
            etc = pkgs.runCommand "box-etc" { } ''
              mkdir $out
              cat <<EOF > $out/passwd
              root:x:0:0:System administrator:/root:/bin/sh
              sprrw:x:1000:100:sprrw:/home/sprrw:/bin/sh
              EOF

              cat <<EOF > $out/group
              root:x:0:
              users:x:100:
              EOF

              cat <<EOF > $out/nsswitch.conf
              passwd:    files
              group:     files
              shadow:    files
              sudoers:   files

              hosts:     files dns
              networks:  files dns

              ethers:    files
              services:  files
              protocols: files
              rpc:       files

              subuid:    files
              subgid:    files
              EOF

              cat <<EOF > $out/resolv.conf
              nameserver 1.1.1.1
              EOF

              mkdir $out/fonts

              echo box > $out/hostname

              cat <<EOF > $out/hosts
              127.0.0.1 localhost
              ::1 localhost
              EOF

              mkdir -p $out/ssl/certs
              ln -s ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt $out/ssl/certs/ca-bundle.crt
              ln -s ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt $out/ssl/certs/ca-certificates.crt
            '';
            usr = pkgs.runCommand "box-usr" { } ''
              mkdir -p $out/bin
              ln -s ${pkgs.coreutils}/bin/env $out/bin
            '';
            lib64 = pkgs.runCommand "box-lib64" { } ''
              mkdir $out
              ln -s ${pkgs.nix-ld}/libexec/nix-ld $out/ld-linux-x86-64.so.2
            '';
            nixLdLibraries = pkgs.buildEnv {
              name = "ld-library-path";
              pathsToLink = [ "/lib" ];
              paths = map lib.getLib (
                with pkgs;
                [
                  zlib
                  zstd
                  stdenv.cc.cc
                  curl
                  openssl
                  attr
                  libssh
                  bzip2
                  libxml2
                  acl
                  libsodium
                  util-linux
                  xz
                  systemd
                ]
              );
              postBuild = ''
                ln -s ${pkgs.stdenv.cc.bintools.dynamicLinker} $out/share/nix-ld/lib/ld.so
              '';
              extraPrefix = "/share/nix-ld";
              ignoreCollisions = true;
            };
            packages = pkgsLinux.buildEnv {
              name = "box-packages";
              pathsToLink = [ "/bin" ];
              paths = with pkgsLinux; [
                coreutils
                bash
                curl
                wget
                dig
                git
                findutils
                gnugrep
                ripgrep
                python3
                brave-search-cli
              ];
            };
          in
          pkgs.runCommand "box" { nativeBuildInputs = with pkgs; [ makeWrapper ]; } ''
            mkdir -p $out/bin
            makeWrapper ${rustBin}/bin/box $out/bin/box \
              ${
                if pkgs.stdenv.hostPlatform.isLinux then
                  ''
                    --set SPRRW_BIN ${bin} \
                    --set SPRRW_ETC ${etc} \
                    --set SPRRW_USR ${usr} \
                    --set SPRRW_LIB64 ${lib64} \
                    --set NIX_LD ${nixLdLibraries}/share/nix-ld/lib/ld.so \
                    --set NIX_LD_LIBRARY_PATH ${nixLdLibraries}/share/nix-ld/lib \
                  ''
                else
                  ""
              } \
              --set SPRRW_PATH ${packages}/bin \
              --set SPRRW_TERMINFO ${terminfo}
          '';
      };
    };
}
