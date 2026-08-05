# Rofi-based emoji picker.
{
  perSystem =
    { pkgs, lib, ... }:
    {
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        emoji-picker = pkgs.writeShellApplication {
          name = "emoji-picker";
          text = ''
            emojis=$(cat <<EOF
            👀 Eyes
            🚫 No
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
            🥺 Pleading
            🙏 Pray
            🙂 Smile
            🙁 Frown
            😳 Flushed
            🫪 Flooshed
            😅 Sweat smile
            😴 Sleeping
            😢 Crying
            EOF
            )
        
            selected=$(echo "$emojis" | ${pkgs.rofi}/bin/rofi -dmenu -i -p "Emoji")
        
            if [ -n "$selected" ]; then
              echo "$selected" | cut -d' ' -f1 | tr -d '\n' | ${pkgs.wl-clipboard}/bin/wl-copy
            fi
          '';
        };
      };
    };
}
