alias ls='ls --color=always'

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

# Necessary because of nix path order
alias vi='nvim'
alias vim='nvim'

function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

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

alias nss='nix-search --channel=25.11 -d -m 3'
alias nss-unstable='nix-search --channel=unstable -d -m 3'

export UV_LINK_MODE=symlink
