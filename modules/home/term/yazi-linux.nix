{
  flake.modules.homeManager.yazi-linux = {
    xdg.mimeApps = {
      enable = true;
      defaultApplications."inode/directory" = "yazi.desktop";
    };
  };
}
