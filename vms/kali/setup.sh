#!/usr/bin/env bash

cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null
set -e

if [[ -f ~/.ssh/kali ]]; then
  echo "Key already exists, using that."
else
  ssh-keygen -f ~/.ssh/kali -P '' || true
fi

if [[ -f kali-ip.txt ]]; then
  export MACHINE_IP="$(cat kali-ip.txt)"
else
  echo "Set up the VM and enter kali:kali as the credentials."
  echo "Then run"
  echo
  echo "sudo systemctl enable --now ssh"
  echo "ip a"

  echo "Enter the IP address of the machine:"
  read -er MACHINE_IP_READ
  export MACHINE_IP="$MACHINE_IP_READ"

  echo "$MACHINE_IP" > kali-ip.txt

  ssh kali@$MACHINE_IP bash <<EOF
set -e
mkdir -p ~/.ssh
echo $(cat ~/.ssh/kali.pub) > ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
EOF
  
  echo "Uploaded key"
fi

run="ssh -i ~/.ssh/kali kali@$MACHINE_IP bash"

# Configure sudo
$run <<EOF
set -e

cat <<OOF > /tmp/sudoers
Defaults        env_reset
Defaults        mail_badpass
Defaults        use_pty

root    ALL=(ALL:ALL) ALL

%sudo   ALL=(ALL:ALL) NOPASSWD:SETENV: ALL

@includedir /etc/sudoers.d
OOF

echo kali | sudo -S chown root:root /tmp/sudoers
echo kali | sudo -S mv /tmp/sudoers /etc/sudoers
EOF

# Configure MTU
if [[ "$(hostname)" == "tanto" ]]; then
  echo "Setting MTU..."
  $run <<EOF
set -e
sudo ip link set eth0 mtu 1280
echo 'sudo ip link set eth0 mtu 1280' >> ~/.xprofile
chmod +x ~/.xprofile
EOF
fi

# Configure ssh
$run <<EOF
set -e

sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh
EOF

echo "Restarted ssh"

# Configure spice and nix
$run <<EOF
set -e

sudo apt-get update
sudo apt-get install -y spice-vdagent curl
sudo systemctl enable --now spice-vdagent

if [[ ! -e /nix/var/nix/profiles/default/bin/nix ]]; then
  sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon --yes
fi

if [[ ! -e ~/.config/nix/nix.conf ]]; then
  mkdir -p ~/.config/nix
  echo "extra-experimental-features = flakes nix-command" > ~/.config/nix/nix.conf
fi
EOF

echo "Configured spice and nix"

./build.sh

$run <<EOF
set -e

sudo apt-get install -y seclists alacritty

touch ~/.hushlogin

sudo chsh -s /bin/bash kali
EOF

$run <<EOF
set -e

if ! grep -q '__ETC_PROFILE_NIX_SOURCED' /etc/profile; then
  sudo sed -iE 's/export PATH/export PATH\\nunset __ETC_PROFILE_NIX_SOURCED/g' /etc/profile
fi

# docker
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  bookworm stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod -a -G docker kali

wget -O /tmp/IosevkaTerm.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/IosevkaTerm.zip
mkdir /tmp/IosevkaTerm && (cd /tmp/IosevkaTerm && unzip ../IosevkaTerm.zip) && sudo mv /tmp/IosevkaTerm/*.ttf /usr/local/share/fonts
rm -rf /tmp/IosevkaTerm.zip /tmp/IosevkaTerm

sudo reboot
EOF

echo "Done!"
