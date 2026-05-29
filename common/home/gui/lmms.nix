{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.sprrw.gui.lmms = {
    enable = lib.mkEnableOption "lmms";
  };

  config =
    let
      cfg = config.sprrw.gui.lmms;
    in
    lib.mkIf cfg.enable {
      home.packages = with pkgs; [
        (runCommand "lmms" { } ''
          mkdir -p $out/share/applications
          cat <<EOF > $out/share/applications/lmms.desktop
          [Desktop Entry]
          Name=LMMS
          GenericName=Music production suite
          GenericName[ca]=Programari de producció musical
          GenericName[de]=Software zur Musik-Produktion
          GenericName[fr]=Suite de production musicale
          GenericName[pl]=Narzędzia do produkcji muzyki
          Comment=Music sequencer and synthesizer
          Comment[ca]=Producció fàcil de música per a tothom!
          Comment[fr]=Séquenceur et synthétiseur de musique
          Comment[pl]=Prosta produkcja muzyki dla każdego!
          Icon=lmms
          Exec=/usr/bin/env QT_QPA_PLATFORM=xcb ${lmms-full}/bin/lmms %f
          Terminal=false
          Type=Application
          Categories=Qt;AudioVideo;Audio;Midi;
          MimeType=application/x-lmms-project;
          EOF
          ln -s ${lmms-full}/share/icons $out/share/icons
        '')
      ];
    };
}
