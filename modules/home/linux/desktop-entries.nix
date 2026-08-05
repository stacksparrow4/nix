{
  # Overwrite default desktop file to rename to "Discord"
  flake.homeModules.linux-desktop-entries = {
    xdg.dataFile."applications/dev.vencord.Vesktop.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Discord (Vesktop)
      GenericName=Internet Messenger
      Comment=Vesktop is a custom Discord App aiming to give you better performance and improve linux support
      Exec=flatpak run dev.vencord.Vesktop %U
      Icon=dev.vencord.Vesktop
      Terminal=false
      Categories=Network;InstantMessaging;Chat;
      Keywords=discord;vencord;vesktop;electron;chat;
      MimeType=x-scheme-handler/discord;
      StartupWMClass=vesktop
      StartupNotify=true
      X-Flatpak=dev.vencord.Vesktop
    '';
  };
}
