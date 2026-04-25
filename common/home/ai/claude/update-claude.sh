#!/usr/bin/env bash

set -e
cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null

newversion=$(box -c 'npm view @anthropic-ai/claude-code version' 2>/dev/null)

echo "Updating to version $newversion"

tdir=$(mktemp -d)
cd "$tdir"
box-cwd <<EOF
wget -O claude.tgz "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-$newversion.tgz"
tar xvf claude.tgz
cd package
AUTHORIZED=1 npm install
EOF

cd -

cp "$tdir/package/package-lock.json" ./

rm -rf "$tdir"
