#!/usr/bin/env bash

TMPDIR="$(mktemp -d)"

ssh-keygen -f "$TMPDIR/key" -N ""
cat <<"EOF" > "$TMPDIR/Dockerfile"
FROM nixos/nix

RUN nix-env -f '<nixpkgs>' -iA openssh busybox su

RUN mkdir -p /etc/ssh /var/empty /root/.ssh /run \
 && echo "sshd:x:498:65534::/var/empty:/run/current-system/sw/bin/nologin" >> /etc/passwd \
 && cp /root/.nix-profile/etc/ssh/sshd_config /etc/ssh \
 && sed -i '/^PermitRootLogin/d' /etc/ssh/sshd_config \
 && echo "PermitRootLogin yes" >> /etc/ssh/sshd_config \
 && ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N "" -t rsa \
 && echo "export NIX_PATH=$NIX_PATH" >> /etc/bashrc \
 && echo "export NIX_SSL_CERT_FILE=$NIX_SSL_CERT_FILE" >> /etc/bashrc \
 && echo "export PATH=$PATH" >> /etc/bashrc \
 && echo "source /etc/bashrc" >> /etc/profile \
 && echo root:badpassword | chpasswd

COPY ./key.pub /root/.ssh/authorized_keys

CMD ["/bin/sh", "-c", "$(which sshd) -D"]
EOF
docker build -t nix-builder "$TMPDIR"

mv "$TMPDIR/key" ~/.ssh/nixbuilder-key

rm -rf "$TMPDIR"

docker run -d -p 2222:22 nix-builder

cat <<EOF
Add the following to /etc/ssh/ssh_config:

Host nixbuilder
  Hostname localhost
  Port 2222
  User root
  IdentityFile ~/.ssh/nixbuilder-key

Then add the following to /etc/nix/nix.conf

trusted-users = root $(whoami)

Then the following to ~/.config/nix/nix.conf

builders = ssh://nixbuilder aarch64-linux

Then restart nix:

sudo launchctl stop org.nixos.nix-daemon && sudo launchctl start org.nixos.nix-daemon

Test it works (and add host key):

sudo ssh nixbuilder
EOF

