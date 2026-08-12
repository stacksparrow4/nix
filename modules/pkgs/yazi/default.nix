{ ... }:

{
  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    let
      inherit (pkgs.stdenv.hostPlatform) isLinux;

      yaziConfig = pkgs.runCommand "sprrw-yazi-config" { } (
        ''
          mkdir -p $out
          install -m644 ${./keymap.toml} $out/keymap.toml
        ''
        + lib.optionalString isLinux ''
          cat ${./keymap-linux.toml} >> $out/keymap.toml
          cp ${./yazi-linux.toml} $out/yazi.toml
        ''
      );

      runtimeDeps =
        (with pkgs; [
          file
          jq
          ffmpegthumbnailer
          poppler-utils
        ])
        ++ lib.optionals isLinux (
          with pkgs;
          [
            xdg-utils
            dragon-drop
          ]
        );

      yazi = pkgs.symlinkJoin {
        name = "yazi";
        paths = [ pkgs.yazi ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/yazi \
            --set YAZI_CONFIG_HOME ${yaziConfig} \
            --prefix PATH : ${lib.makeBinPath runtimeDeps}
        '';
      };
    in
    {
      packages = {
        inherit yazi;
      };
    };
}
