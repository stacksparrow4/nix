{
  sprrw.flatpaks = [
    {
      name = "dev.vencord.Vesktop";
      # Maybe should "set" the permissions rather than removing
      extraCommands = "flatpak override --user --nosocket=x11 --nofilesystem=~/.steam dev.vencord.Vesktop";
    }
    {
      name = "org.libreoffice.LibreOffice";
    }
    {
      name = "com.usebruno.Bruno";
      # Possibly should remove home directory permission
    }
  ];
}
