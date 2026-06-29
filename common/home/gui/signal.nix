{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.sprrw.gui.signal = {
    enable = lib.mkEnableOption "signal";
  };

  config =
    let
      cfg = config.sprrw.gui.signal;
    in
    lib.mkIf cfg.enable {
      home.packages = with pkgs; [
        (runCommand "signal" { } ''
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
        '')
      ];
    };
}
