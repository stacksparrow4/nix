{
  perSystem =
    { pkgs, lib, ... }:
    {
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        portal-chooser = pkgs.writeShellApplication {
          name = "portal-chooser";

          runtimeInputs = with pkgs; [
            jq
            rofi
            slurp
            sway
          ];

          text = builtins.readFile ./portal-chooser.sh;
        };
      };
    };
}
