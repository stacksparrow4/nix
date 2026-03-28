{
  sprrw.flatpaks = [
    {
      name = "dev.vencord.Vesktop";
      extraCommands = "flatpak override --user --nosocket=x11 --nofilesystem=~/.steam dev.vencord.Vesktop";
    }
    {
      name = "org.libreoffice.LibreOffice";
    }
  ];
}
