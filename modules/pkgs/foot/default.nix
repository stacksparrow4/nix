{
  perSystem =
    { pkgs, lib, ... }:
    {
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        foot = pkgs.symlinkJoin {
          name = "foot";
          paths = [ pkgs.foot ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/foot --add-flags "--config=${./foot.ini}"
          '';
          passthru = { inherit (pkgs.foot) terminfo; };
        };
      };
    };
}
