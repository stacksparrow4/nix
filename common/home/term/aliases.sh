alias ls='ls --color=auto'

alias ggpush='git push -u origin $(git branch --show-current)'
alias ggpull='git pull'
alias ga='git add'
alias gd='git diff'
alias gds='git diff --staged'
alias gcmsg='git commit -m'
alias gacmsg='git add . && git commit -m'
alias gamsg='git add . && git commit -m'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gst='git status'
alias gcm='git checkout main || git checkout master'
alias glog='git log'
alias gds='git diff --staged'
alias gf='git fetch'
alias grv='git remote -v'
alias gbv='git branch -v'

function take() {
  if [[ $# -ne 1 ]]; then
    echo "Usage: take path/to/dir"
  fi
  mkdir -p "$1"
  cd "$1"
}

function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	command yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}

function rl() {
  local mypath
  if echo "$1" | grep -qE "^/"; then
    mypath="$1"
  else
    if ! which "$1" >/dev/null; then
      echo "Failed to find binary"
      return 1
    fi
    mypath=$(which "$1")
  fi

  while [ -L "$mypath" ]; do
    echo "$mypath"
    mypath=$(readlink "$mypath")
  done

  echo "$mypath"
}

if which navi &>/dev/null && [[ $- == *i* ]]; then
  _navi_widget() {
    result="$(navi --print < /dev/tty)"
    echo -n "$result" | wl-copy
  }

  bind -x '"\C-g": _navi_widget'
fi

# Necessary because of nix path order
alias vi='nvim'
alias vim='nvim'

function ns() {
  if [[ -n "$BASH_VERSINFO" ]]; then
    history -a
  fi
  nix-shell -p "$@"
}

function ns-unstable() {
  if [[ -n "$BASH_VERSINFO" ]]; then
    history -a
  fi
  NIXPKGS_ALLOW_UNFREE=1 nix shell --impure $(for i in "$@"; do echo -n ' github:NixOS/nixpkgs/nixos-unstable#'"$i"; done)
}

function pkgsrc() { pos=$(nix-instantiate --json --eval -E '(import <nixpkgs> {}).'"$1"'.meta.position' | jq -r .); fname=$(echo "$pos" | cut -d: -f1); fpos=$(echo "$pos" | cut -d: -f2); vim +"$fpos" "$fname"; }

alias nss='nix-search --channel=25.11 -d -m 3'
alias nss-unstable='nix-search --channel=unstable -d -m 3'

export UV_LINK_MODE=symlink

alias nixurl='nix store prefetch-file'

alias qwen='aichat -m ollama:qwen3-coder:30b'
alias claude='aichat -m bedrock:global.anthropic.claude-opus-4-6-v1'
