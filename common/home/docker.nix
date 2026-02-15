{
  # Need to find a way to stop this conflicting with stuff
  home.file.".docker/config.json".text = ''
    {
        "detachKeys": "ctrl-z,z"
    }
  '';
}
