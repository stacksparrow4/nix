monitors=()
windows=()

while IFS= read -r label || [[ -n $label ]]; do
  case "$label" in
    "Monitor: "*) monitors+=("$label") ;;
    "Window: "*) windows+=("$label") ;;
  esac
done

if ((${#monitors[@]} == 0)) && ((${#windows[@]} == 0)); then
  printf 'portal-chooser: no candidate sources on stdin\n' >&2
  exit 1
fi

ensure_swaysock() {
  local sock

  if [[ -n ${SWAYSOCK:-} && -S ${SWAYSOCK:-} ]] && swaymsg -t get_version >/dev/null 2>&1; then
    return 0
  fi

  for sock in "${XDG_RUNTIME_DIR:-/run/user/$UID}"/sway-ipc.*.sock; do
    if [[ -S $sock ]] && SWAYSOCK=$sock swaymsg -t get_version >/dev/null 2>&1; then
      export SWAYSOCK=$sock
      return 0
    fi
  done

  printf 'portal-chooser: no usable sway IPC socket (SWAYSOCK=%s)\n' "${SWAYSOCK:-unset}" >&2
  return 1
}

monitor_regions() {
  local outputs label rest name geom
  outputs=$(swaymsg -t get_outputs)

  for label in "${monitors[@]}"; do
    rest=${label#"Monitor: "}
    name=${rest%% *}
    geom=$(jq -r --arg name "$name" '
      .[]
      | select(.name == $name and .active and .rect.width > 0 and .rect.height > 0)
      | "\(.rect.x),\(.rect.y) \(.rect.width)x\(.rect.height)"
    ' <<<"$outputs")

    if [[ -n $geom ]]; then
      printf '%s %s\n' "$geom" "$label"
    fi
  done
}

window_regions() {
  local views line rest id title geom label
  declare -A geom_by_id=()
  declare -A geom_by_title=()

  views=$(swaymsg -t get_tree | jq -r '
    [recurse(.nodes[]?, .floating_nodes[]?)][]
    | select(.visible == true and .rect.width > 0 and .rect.height > 0)
    | [(.foreign_toplevel_identifier // ""), (.name // ""),
       "\(.rect.x),\(.rect.y) \(.rect.width)x\(.rect.height)"]
    | @tsv
  ')

  while IFS= read -r line; do
    id=${line%%$'\t'*}
    rest=${line#*$'\t'}
    title=${rest%%$'\t'*}
    geom=${rest#*$'\t'}

    if [[ -n $id ]]; then
      geom_by_id[$id]=$geom
    fi
    if [[ -n $title && -z ${geom_by_title[$title]:-} ]]; then
      geom_by_title[$title]=$geom
    fi
  done <<<"$views"

  for label in "${windows[@]}"; do
    if [[ $label =~ ^Window:\ (.*)\ \((.*)\)$ ]]; then
      title=${BASH_REMATCH[1]}
      id=${BASH_REMATCH[2]}
    else
      continue
    fi

    geom=""
    if [[ -n $id ]]; then
      geom=${geom_by_id[$id]:-}
    fi
    if [[ -z $geom && -n $title ]]; then
      geom=${geom_by_title[$title]:-}
    fi

    if [[ -n $geom ]]; then
      printf '%s %s\n' "$geom" "$label"
    fi
  done
}

mode=""
if ((${#monitors[@]} > 0)) && ((${#windows[@]} > 0)); then
  mode=$(printf 'Monitor\nWindow\n' | rofi -dmenu -i -p 'Share') || exit 1
elif ((${#monitors[@]} > 0)); then
  mode="Monitor"
else
  mode="Window"
fi

ensure_swaysock || exit 1

case "$mode" in
  Monitor) regions=$(monitor_regions) ;;
  Window) regions=$(window_regions) ;;
  *) exit 1 ;;
esac

if [[ -z $regions ]]; then
  printf 'portal-chooser: no selectable %s sources on screen\n' "${mode,,}" >&2
  exit 1
fi

selection=$(printf '%s\n' "$regions" | slurp -r -f '%l') || exit 1

for label in ${monitors[@]+"${monitors[@]}"} ${windows[@]+"${windows[@]}"}; do
  if [[ $label == "$selection" ]]; then
    printf '%s\n' "$selection"
    exit 0
  fi
done

printf 'portal-chooser: slurp returned an unknown label: %s\n' "$selection" >&2
exit 1
