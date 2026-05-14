{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.sprrw.gui.emoji-picker = {
    enable = lib.mkEnableOption "emoji-picker";
  };

  config =
    let
      cfg = config.sprrw.gui.emoji-picker;
    in
    lib.mkIf cfg.enable {
      home.packages = [
        (pkgs.writeShellApplication {
          name = "emoji-picker";
          text = ''
            emojis=$(cat <<EOF
            👀 Eyes
            🚫 Prohibited
            👍 Thumbs Up
            👎 Thumbs Down
            🔥 Fire
            💀 Skull
            😂 Joy
            😭 Sob
            🤔 Thinking
            🎉 Party
            🚀 Rocket
            ✔️ Check
            ❌ Cross
            ❤️ Heart
            EOF
            )

            selected=$(echo "$emojis" | ${pkgs.rofi}/bin/rofi -dmenu -i -p "Emoji")

            if [ -n "$selected" ]; then
              echo "$selected" | cut -d' ' -f1 | tr -d '\n' | ${pkgs.wl-clipboard}/bin/wl-copy
            fi
          '';
        })
      ];
    };
}
