{
  pkgs,
  model,
}:

pkgs.writeShellApplication {
  name = "pi-convert";
  text = ''
    if [[ $# -ne 1 ]]; then
      echo "Usage: $0 <conversion-prompt>"
      exit 1
    fi

    pi \
      --system "$1. Do not output markdown or any additional explanation, only the raw output." \
      -p --no-tools --no-extensions \
      -- \
      --model ${model}
  '';
}
