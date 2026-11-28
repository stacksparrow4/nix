{
  perSystem =
    {
      pkgs,
      system,
      ...
    }:
    let
      noitaProxy =
        (builtins.getFlake "github:IntQuant/noita_entangled_worlds/99674cda7f0e0950466138fc552b44287d34b3d5")
        .packages.${system}.default;
    in
    {
      packages.noita-ew = pkgs.writeTextFile {
        name = "noita-ew";
        executable = true;
        destination = "/bin/noita-ew";
        text = ''
          #!/bin/sh
          unset LD_PRELOAD LD_AUDIT
          export LD_LIBRARY_PATH=/run/opengl-driver/lib:/run/opengl-driver-32/lib
          ${pkgs.coreutils}/bin/mkdir -p "$HOME/.config/entangledworlds"
          if [ ! -e "$HOME/.config/entangledworlds/proxy.ron" ]; then
            ${pkgs.coreutils}/bin/cat > "$HOME/.config/entangledworlds/proxy.ron" <<RON
          (paths:(noita_exe:Some("$HOME/.local/share/Steam/steamapps/common/Noita/noita.exe")))
          RON
          fi
          export NP_APPID=881100
          exec ${noitaProxy}/bin/noita_proxy "$@"
        '';
      };
    };
}
