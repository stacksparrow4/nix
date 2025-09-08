#!/usr/bin/env bash

set -e

if ! (yq --version | grep -q 'version v4'); then
  echo "Please install yq from https://github.com/mikefarah/yq"
  exit 1
fi

function help() {
  echo "Available commands:"
  echo "windows-yaml.sh init"
  echo "windows-yaml.sh adduser <username> [<password>]"
  echo "windows-yaml.sh addusers <userlist.txt>"
  echo "  windows-yaml.sh adduserpassword <username> <password>"
  echo "  windows-yaml.sh addntlm <username> <ntlm_hash> or windows-yaml.sh addntlm <username> <nt_hash>"
  echo "  windows-yaml.sh addpfx <username> <path/to/pfx.pfx>"
  echo "  windows-yaml.sh addccache <username> <path/to/ccache.ccache>"
  echo "windows-yaml.sh addpassword <password>"
  echo "windows-yaml.sh addip <ip>"
  echo "windows-yaml.sh addips <ips.txt>"
  echo "windows-yaml.sh addfqdn <ip> <fqdn>"
  echo "windows-yaml.sh adddc <ip> <domain>"
  echo "windows-yaml.sh writelist"
  exit 1
}

checkargs_global_numargs=$#
function checkargs() {
  if [[ "$checkargs_global_numargs" -ne "$1" ]]; then
    help
  fi
}

function inityamlfile() {
  cat > windows.yaml <<EOF
users:
  # Note: default credentials. Should always be in password sprays
  - username: root
  - username: admin
  - password: password
  - password: admin
  - password: root
  # End default creds
hosts: []
EOF
  echo "Initialised windows.yaml"
}

function confirmproceed() {
  read line
  [[ "$line" == "y" ]] || [[ "$line" == "Y" ]]
}

function safeinityamlfile() {
  if [[ -f windows.yaml ]]; then
    echo "windows.yaml already exists. Do you want to replace it? (y/n)"
    if confirmproceed; then
      inityamlfile
    else
      echo "not replacing windows.yaml as it already exists"
    fi
  else
    inityamlfile
  fi
}

function initifnotexists() {
  if ! [[ -f windows.yaml ]]; then
    inityamlfile
  fi
}

function adduser() {
  initifnotexists
  if [[ -n "$(USERNAME="$1" yq '.users[] | select ((.username | downcase) == (strenv(USERNAME) | downcase))' windows.yaml)" ]]; then
    echo "Warning: skipping adding user $1 as they already exist"
  else
    USERNAME="$1" yq -i '.users += { "username": strenv(USERNAME) }' windows.yaml
    echo "Added user $1"
  fi
}

function checkandadduser() {
  initifnotexists
  if [[ -z "$(USERNAME="$1" yq '.users[] | select ((.username | downcase) == (strenv(USERNAME) | downcase))' windows.yaml)" ]]; then
    echo "User $1 does not exist. Do you wish to add them? (y/n)"
    if confirmproceed; then
      USERNAME="$1" yq -i '.users += { "username": strenv(USERNAME) }' windows.yaml
    else
      return 1
    fi
  fi
  return 0
}

function checkuserhaskey() {
  [[ "$(USERNAME="$1" KEY="$2" yq '.users[] | select ((.username | downcase) == (strenv(USERNAME) | downcase)) | has(strenv(KEY))' windows.yaml)" == "true" ]]
}

function confirmoverrideuserkey() {
  if checkuserhaskey "$1" "$2"; then
    echo "User $1 already has key $2. Do you wish to override? (y/n)"
    if ! confirmproceed; then
      echo "Skipping user $1"
      return 1
    fi
  fi
  return 0
}

function writeuserkey() {
  checkandadduser "$1"
  if confirmoverrideuserkey "$1" "$2"; then
    USERNAME="$1" VAL="$3" yq -i '(.users[] | select ((.username | downcase) == (strenv(USERNAME) | downcase)) | .'"$2"') = strenv(VAL)' windows.yaml
    echo "Updated $2 for user $1"
  fi
}

function adduserpassword() {
  writeuserkey "$1" password "$2"
}

function addntlm() {
  local lm_hash=""
  if echo "$2" | grep -q ':'; then
    local lm_hash=$(echo "$2" | cut -d: -f1)
    local nt_hash=$(echo "$2" | cut -d: -f2)
  else
    local nt_hash="$2"
  fi

  if [[ -n "$lm_hash" ]]; then
    echo "Writing LM hash $lm_hash"
    writeuserkey "$1" lm_hash "$lm_hash"
  fi

  echo "Writing NT hash $nt_hash"
  writeuserkey "$1" nt_hash "$nt_hash"
}

function addpfx() {
  writeuserkey "$1" pfx_path "$2"
}

function addccache() {
  checkandadduser "$1"
  if [[ "$(USERNAME="$1" yq '.users[] | select ((.username | downcase) == (strenv(USERNAME) | downcase)) | has("ccache_paths")' windows.yaml)" == "false" ]]; then
    USERNAME="$1" yq -i '(.users[] | select ((.username | downcase) == (strenv(USERNAME) | downcase)) | .ccache_paths) = []' windows.yaml
  fi
  USERNAME="$1" CCACHE="$2" yq -i '(.users[] | select ((.username | downcase) == (strenv(USERNAME) | downcase)) | .ccache_paths) += strenv(CCACHE)' windows.yaml
}

function addpassword() {
  PASSWORD="$1" yq -i '.users += { "password": strenv(PASSWORD) }' windows.yaml
}

function addstrlist() {
  local singularform="$(echo -n "$1" | head -c -1)"
  initifnotexists
  if [[ -n "$(VAL="$2" yq '.'"$1"'[] | select ((. | downcase) == (strenv(VAL) | downcase))' windows.yaml)" ]]; then
    echo "Warning: skipping adding duplicate $singularform $2"
  else
    VAL="$2" yq -i '.'"$1"' += strenv(VAL)' windows.yaml
    echo "Added $singularform $2"
  fi
}

function addip() {
  initifnotexists
  if [[ -z "$(IP="$1" yq '.hosts[] | select (.ip == strenv(IP))' windows.yaml)" ]]; then
    IP="$1" yq -i '.hosts += { "ip": strenv(IP) }' windows.yaml
    echo "Added ip $1"
  fi
}

function addfqdn() {
  addip "$1"
  IP="$1" DOMAIN="$2" yq -i '(.hosts[] | select (.ip == strenv(IP)) | .fqdn) = strenv(DOMAIN)' windows.yaml
}

function adddc() {
  addip "$1"
  IP="$1" DOMAIN="$2" yq -i '(.hosts[] | select (.ip == strenv(IP)) | .dcdomain) = strenv(DOMAIN)' windows.yaml
}

if [[ $# -eq 0 ]]; then
  help
fi

case "$1" in
  init)
    checkargs 1
    safeinityamlfile
    ;;
  adduser)
    if [[ $# -eq 2 ]]; then
      adduser "$2"
    elif [[ $# -eq 3 ]]; then
      adduser "$2"
      USERNAME="$2" VAL="$3" yq -i '(.users[] | select ((.username | downcase) == (strenv(USERNAME) | downcase)) | .password) = strenv(VAL)' windows.yaml
      echo "Wrote password for user $1"
    else
      help
    fi
    ;;
  addusers)
    checkargs 2
    cat "$2" | while read user; do
      adduser "$user"
    done
    echo "Finished adding users"
    ;;
  adduserpassword)
    checkargs 3
    adduserpassword "$2" "$3"
    ;;
  addntlm)
    checkargs 3
    addntlm "$2" "$3"
    ;;
  addpfx)
    checkargs 3
    addpfx "$2" "$3"
    ;;
  addccache)
    checkargs 3
    addccache "$2" "$3"
    ;;
  addpassword)
    checkargs 2
    addpassword "$2"
    ;;
  addip)
    checkargs 2
    addip "$2"
    ;;
  addips)
    checkargs 2
    for i in $(cat $2); do
      addip "$i"
    done
    ;;
  addfqdn)
    checkargs 3
    addfqdn "$2" "$3"
    ;;
  adddc)
    checkargs 3
    adddc "$2" "$3"
    ;;
  writelist)
    checkargs 1
    yq '.users[].username | select (. != null)' windows.yaml | sort -u > .users
    yq '.users[].password | select (. != null)' windows.yaml | sort -u > .passwords
    yq '.hosts[].ip | select (. != null)' windows.yaml | sort -u > .ips
    yq '.hosts[].fqdn | select (. != null)' windows.yaml | sort -u > .fqdns
    ;;
  *)
    echo "Unrecognised command"
    help
    ;;
esac
