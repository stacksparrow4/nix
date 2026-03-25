#!/usr/bin/env bash

set -e

git add .

isopath=$(nixos-rebuild build-image --flake .#sandbox --image-variant iso --no-link)

echo "$isopath"

open_port=$(comm -23 <(seq 49152 65535) <(ss -tan | awk '{print $4}' | cut -d':' -f2 | grep "[0-9]\{1,5\}" | sort | uniq) | shuf | head -n 1)

echo "Forwarding SSH to port $open_port"

pidfile=$(mktemp)

qemu-system-x86_64 -enable-kvm -m 4096 -cdrom "$isopath" -boot d -nic user,hostfwd=tcp:127.0.0.1:"$open_port"-:22 -display none -daemonize -pidfile "$pidfile"

qemupid=$(cat "$pidfile")

echo "Process id $qemupid"

sshpass -p password ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null localhost -p $open_port || true

echo "Terminating qemu..."

kill "$qemupid"

echo "Done!"
