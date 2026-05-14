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
    echo -n "$output" | ${pkgs.wl-clipboard}/bin/wl-copy
    printf "\e[32mCopied to clipboard\e[0m"
  '';
}
