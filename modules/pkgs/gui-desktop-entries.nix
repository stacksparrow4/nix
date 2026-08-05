{
  perSystem =
    {
      pkgs,
      pkgs-unstable,
      lib,
      ...
    }:
    {
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        lmms-desktop-entry = pkgs.runCommand "lmms" { } ''
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
          Exec=/usr/bin/env QT_QPA_PLATFORM=xcb ${pkgs.lmms-full}/bin/lmms %f
          Terminal=false
          Type=Application
          Categories=Qt;AudioVideo;Audio;Midi;
          MimeType=application/x-lmms-project;
          EOF
          ln -s ${pkgs.lmms-full}/share/icons $out/share/icons
        '';

        signal-desktop-entry =
          let
            signal-desktop = pkgs-unstable.signal-desktop;
          in
          pkgs.runCommand "signal" { } ''
            mkdir -p $out/share/applications
            cat <<EOF > $out/share/applications/signal.desktop
            [Desktop Entry]
            Name=Signal
            Exec=${signal-desktop}/bin/signal-desktop --disable-gpu %U
            Terminal=false
            Type=Application
            Icon=signal-desktop
            StartupWMClass=signal
            Comment=Private messaging from your desktop
            MimeType=x-scheme-handler/sgnl;x-scheme-handler/signalcaptcha;
            Categories=Network;InstantMessaging;Chat;
            EOF
            ln -s ${signal-desktop}/share/icons $out/share/icons
          '';
      };
    };
}
