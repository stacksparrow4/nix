# Sandboxed wrappers for the forensics tooling.
{
  perSystem =
    {
      pkgs,
      lib,
      mkSandbox,
      ...
    }:
    let
      cwdOnly =
        name: prog:
        mkSandbox {
          inherit name prog;
          shareCwd = true;
        };
    in
    {
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        exiftool = cwdOnly "exiftool" "${pkgs.exiftool}/bin/exiftool";
        binwalk = cwdOnly "binwalk" "${pkgs.binwalk}/bin/binwalk";
        ent = cwdOnly "ent" "${pkgs.ent}/bin/ent";
      };
    };
}
