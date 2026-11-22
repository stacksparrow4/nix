{
  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      packages.yazi = pkgs.symlinkJoin {
        name = "yazi";
        paths = [ pkgs.yazi ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          for prog in yazi ya; do
            wrapProgram "$out/bin/$prog" \
              --set YAZI_CONFIG_HOME ${./config} \
              --prefix PATH : ${
                lib.makeBinPath (
                  with pkgs;
                  [
                    git
                    file
                    jq
                    ffmpegthumbnailer
                    poppler-utils
                    xdg-utils
                    dragon-drop
                  ]
                )
              }
          done
        '';
      };
    };
}
