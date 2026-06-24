{
  pkgs,
  model,
  system,
  name,
}:

let
  systemFile = pkgs.writeText "exec-system" system;
in
pkgs.writeShellApplication {
  inherit name;
  text = ''
    output=$(pi --system "$(cat ${systemFile})" -p --no-tools --no-extensions -- --model ${model} --thinking off "$@" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    echo "$output"
    printf "\n\e[33m[e]\e[0m exec  \e[33m[c]\e[0m copy: "
    read -r choice
    case "$choice" in
      e)
        eval "$output"
        ;;
      c)
        echo -n "$output" | ${pkgs.wl-clipboard}/bin/wl-copy
        printf "\e[32mCopied to clipboard\e[0m\n"
        ;;
      *)
        printf "\e[31mAborted\e[0m\n"
        ;;
    esac
  '';
}
