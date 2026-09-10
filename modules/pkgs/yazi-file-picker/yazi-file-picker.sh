directory="$2"
save="$3"
path="$4"
out="$5"

if [ -z "$path" ]; then
  path="$HOME"
fi

if [ "${6:-0}" -ge 4 ]; then
  set -x
fi

if [ "$save" = "1" ]; then
  set -- --chooser-file="$out" "$path"
elif [ "$directory" = "1" ]; then
  set -- --chooser-file="$out" --cwd-file="$out.1" "$path"
else
  set -- --chooser-file="$out" "$path"
fi

foot --title 'termfilechooser' yazi "$@"

if [ "$directory" = "1" ]; then
  if [ ! -s "$out" ] && [ -s "$out.1" ]; then
    cat "$out.1" >"$out"
  fi
  rm -f "$out.1"
fi
