{
  pkgs,
  config,
  mkSandbox,
  extraModels,
  model,
  name,
}:

let
  pi-convert-sandbox = import ./pi-sandbox.nix {
    inherit
      pkgs
      config
      mkSandbox
      extraModels
      ;
    system = "system-code.md"; # This will be overwritten with --system-prompt
    name = "pi-convert-sandbox";
    extensions = [ ];
    tools = [ ];
    network = true;
  };
in
pkgs.writeShellApplication {
  inherit name;
  text = ''
    if [[ $# -ne 1 ]]; then
      echo "Usage: $0 <conversion-prompt>"
      exit 1
    fi

    ${pi-convert-sandbox}/bin/pi-convert-sandbox \
      --model ${model} \
      --system-prompt "$1. Do not output markdown or any additional explanation, only the raw output." \
  '';
}
