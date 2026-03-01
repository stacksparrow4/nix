{ pkgs, lib, config, ... }:

{
  imports = [
    ../../../common/home
  ];


  sprrw = {
    ai.enable = true;
    linux.enable = true;
    nvim.enable = true;
    programming.enable = true;
    programming.sage.enable = lib.mkForce true;
    sec.enable = true;
    term.enable = true;
    gui.enable = true;
    docker-config.enable = true;
  };

  home = {
    packages = with pkgs; [
      (
        runCommand "signal" {} ''
          mkdir -p $out/share/applications
          cat <<EOF > $out/share/applications/signal.desktop
          [Desktop Entry]
          Name=Signal
          Exec=env QT_QPA_PLATFORM=xcb ${signal-desktop-bin}/bin/signal-desktop --disable-gpu %U
          Terminal=false
          Type=Application
          Icon=signal-desktop
          StartupWMClass=signal
          Comment=Private messaging from your desktop
          MimeType=x-scheme-handler/sgnl;x-scheme-handler/signalcaptcha;
          Categories=Network;InstantMessaging;Chat;
          EOF
          ln -s ${signal-desktop-bin}/share/icons $out/share/icons
        ''
      )
      lmms
      audacity
      aseprite
      vesktop
      (lib.hiPrio (brave.override { commandLineArgs = "--use-gl=egl"; }))
    ];

    username = "sprrw";
    homeDirectory = "/home/sprrw";

    file.".background-image".source = ../bg.png;

    file.".config/sway/conf.d/nest01".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/hosts/nest01/home/sway.config";
    file.".config/kanshi/config".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/hosts/nest01/home/kanshi.config";
  };
}
