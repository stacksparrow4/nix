{
  pkgs,
  config,
  mkSandbox,
  extraModels,
  execModel,
  system,
  name,
}:

let
  pi-exec-sandbox = import ./pi-sandbox.nix {
    inherit
      pkgs
      config
      mkSandbox
      extraModels
      system
      ;
    name = "pi-exec-sandbox";
    extensions = [ ];
    tools = [ ];
    network = true;
  };
in
pkgs.writeShellApplication {
  inherit name;
  text = ''
    output=$(${pi-exec-sandbox}/bin/pi-exec-sandbox --model ${execModel} -p "$@")
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
