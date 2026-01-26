{ pkgs, lib, config, ... }:

{
  options.sprrw.sec.caido = {
    enable = lib.mkEnableOption "caido";
  };

  config = let
    cfg = config.sprrw.sec.caido;
    caido = pkgs.callPackage (
      {
        fetchurl,
        appimageTools,
        makeWrapper,
      }:
      let
        pname = "caido";
        version = "0.55.1";

        desktop = fetchurl {
          url = "https://caido.download/releases/v${version}/caido-desktop-v${version}-linux-x86_64.AppImage";
          hash = "sha256-zfts2h8QWTxe/dISwgKRQiSx2nD6vtE1atPfREyGX/U=";
        };

        appimageContents = appimageTools.extractType2 {
          inherit pname version;
          src = desktop;
        };

      in appimageTools.wrapType2 {
        src = desktop;
        inherit pname version;

        nativeBuildInputs = [ makeWrapper ];

        extraPkgs = pkgs: with pkgs; [ libthai chromium ];

        extraInstallCommands = ''
          install -m 444 -D ${appimageContents}/caido.desktop -t $out/share/applications
          install -m 444 -D ${appimageContents}/caido.png \
            $out/share/icons/hicolor/512x512/apps/caido.png
          wrapProgram $out/bin/caido \
            --set WEBKIT_DISABLE_COMPOSITING_MODE 1 \
            --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"
        '';
      }
    ) {};
  in lib.mkIf cfg.enable {
    home.packages = [
      (pkgs.runCommand "caido-wrapper" {} ''
       mkdir -p $out/share/applications
       cat ${caido}/share/applications/caido.desktop | sed 's/Exec=.*/Exec=caido %U/' > $out/share/applications/caido.desktop
       ln -s ${caido}/share/icons $out/share/icons
       ln -s ${caido}/bin $out/bin
       '')
    ];
  };
}
