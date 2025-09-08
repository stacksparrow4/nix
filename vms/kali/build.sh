#!/usr/bin/env bash

cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null
set -e

if [[ ! -f kali-ip.txt ]]; then
  echo "Error: kali-ip.txt doesn't exist"
  exit 1
fi

export MACHINE_IP="$(cat kali-ip.txt)"

rm -f /tmp/nix.zip && (cd ../../ && zip -r /tmp/nix.zip *)

scp -i ~/.ssh/kali /tmp/nix.zip kali@$MACHINE_IP:/tmp/nix.zip
rm /tmp/nix.zip

ssh -i ~/.ssh/kali kali@$MACHINE_IP bash <<EOF
set -e

rm -rf ~/nixos
mkdir ~/nixos
cd ~/nixos
unzip /tmp/nix.zip
rm /tmp/nix.zip

git init
export PATH=/home/kali/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/home/kali/.local/bin:/usr/local/sbin:/usr/sbin:/sbin:/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games
./build.sh
EOF
