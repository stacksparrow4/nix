{
  perSystem =
    {
      system,
      self',
      ...
    }:
    {
      packages.noita-ew = self'.wrappers.mkSandbox {
        name = "noita-ew";
        prog = "${
          (builtins.getFlake "github:IntQuant/noita_entangled_worlds/99674cda7f0e0950466138fc552b44287d34b3d5")
          .packages.${system}.default
        }/bin/noita_proxy";
        network = true;
        gpu = true;
        wayland = true;
        outsideBeforeScript = ''
          mkdir -p "$HOME/.config/entangledworlds"
          if [ ! -e "$HOME/.config/entangledworlds/proxy.ron" ]; then
            cat > "$HOME/.config/entangledworlds/proxy.ron" <<'RON'
          (paths:(noita_exe:Some("/root/.local/share/Steam/steamapps/common/Noita/noita.exe")))
          RON
          fi
        '';
        sharedPaths =

          let
            steam = "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam";
            noita = "${steam}/steamapps/common/Noita";
          in
          [
            {
              hostPath = noita;
              boxPath = "~/.local/share/Steam/steamapps/common/Noita";
              ro = true;
              type = "dir";
            }
            {
              hostPath = "${noita}/mods";
              boxPath = "~/.local/share/Steam/steamapps/common/Noita/mods";
              ro = false;
              type = "dir";
            }
            {
              hostPath = "${steam}/steamapps/compatdata/881100";
              boxPath = "~/.local/share/Steam/steamapps/compatdata/881100";
              ro = true;
              type = "dir";
            }
            {
              hostPath = "$HOME/.config/entangledworlds";
              boxPath = "~/.config/entangledworlds";
              ro = false;
              type = "dir";
            }
            {
              hostPath = "$HOME/.local/share/entangledworlds";
              boxPath = "~/.local/share/entangledworlds";
              ro = false;
              type = "dir";
            }
          ];
      };
    };
}
