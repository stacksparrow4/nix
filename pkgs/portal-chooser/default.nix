{
  pkgs,
}:

pkgs.writeShellApplication {
  name = "portal-chooser";

  runtimeInputs = with pkgs; [
    jq
    rofi
    slurp
    sway
  ];

  text = builtins.readFile ./portal-chooser.sh;
}
