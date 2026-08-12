{
  flake.homeModules.term-yazi-linux = {
    xdg.mimeApps = {
      enable = true;
      defaultApplications."inode/directory" = "yazi.desktop";
    };
  };
}
