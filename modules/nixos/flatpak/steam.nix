{
  flake.modules.nixos.steam = {
    services.flatpak = {
      packages = [
        {
          appId = "org.freedesktop.Platform.VulkanLayer.gamescope//26.08";
          origin = "flathub";
        }
        {
          appId = "com.valvesoftware.Steam.CompatibilityTool.Proton-GE";
          origin = "flathub";
        }
        {
          appId = "com.valvesoftware.Steam";
          origin = "flathub";
        }
        {
          appId = "io.github.everestapi.Olympus";
          origin = "flathub";
        }
      ];

      overrides = {
        "com.valvesoftware.Steam".Context = {
          filesystems = [
            "!xdg-config/MangoHud"
            "!xdg-music"
            "!xdg-pictures"
            "!xdg-run/app/com.discordapp.Discord"
            "!/run/media"
            "!/mnt"
            "!/media"
          ];
        };
        "io.github.everestapi.Olympus".Context = {
          filesystems = [
            "!home"
            "!/run/media"
          ];
        };
      };
    };
  };
}
