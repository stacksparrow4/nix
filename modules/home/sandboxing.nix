{ moduleWithSystem, ... }:

{
  flake.modules.homeManager.sandbox = moduleWithSystem (
    { self', ... }:
    { pkgs, config, ... }:
    {
      home.packages = [
        self'.packages.box
      ] ++ (if pkgs.stdenv.hostPlatform.isLinux then [
        (pkgs.writeShellApplication {
          name = "build-vm";
          text = ''
            cd ~/${config.sprrw.nixosRepoPath}
            git add .

            imagepath=$(nixos-rebuild build-image --flake .#vm --image-variant qemu --no-link)
            echo "$imagepath"

            mkdir -p ~/.local

            rm -f ~/.local/vm.qcow2
            ln -s "$imagepath" ~/.local/vm.qcow2
          '';
        })
        (pkgs.writeShellApplication {
          name = "vm-enter";
          text = ''
            ports=$(ss -tlpn | grep qemu-system | grep -oE '127\.0\.0\.1:[0-9]+' | cut -d: -f2)

            if [[ -z "$ports" ]]; then
              echo "No valid vms found"
              exit 1
            fi

            target=$(echo "$ports" | while read -r line; do
              echo "$line - $(sshpass -p password ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password localhost -p "$line" ps aux 2>/dev/null | grep pts | awk '{print $11}' | tr '\n' ' ')";
            done | fzf | awk '{print $1}')

            if [[ -z "$target" ]]; then
              echo "Cancelled."
              exit 1
            fi

            sshpass -p password ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password localhost -p "$target"
          '';
        })
      ] else []);

      sprrw.term.shellExtra = ''
        alias b='box'
        alias bc='box --cwd'
      '';
    }
  );
}
