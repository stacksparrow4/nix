{
  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      packages.yazi =
        pkgs.runCommand "yazi"
          {
            nativeBuildInputs = [ pkgs.makeWrapper ];
          }
          ''
            mkdir -p $out/bin
            ln -s ${pkgs.yazi}/bin/yazi $out/bin
            wrapProgram $out/bin/yazi \
              --set YAZI_CONFIG_HOME ${./config} \
              --prefix PATH : ${
                lib.makeBinPath (
                  with pkgs;
                  [
                    file
                    jq
                    ffmpegthumbnailer
                    poppler-utils
                    xdg-utils
                    dragon-drop
                  ]
                )
              }
          '';
    };
}
