{
  perSystem =
    {
      pkgs,
      ...
    }:
    {
      packages.build-vm = pkgs.writeShellApplication {
        name = "build-vm";
        text = ''
          cd ~/nixos
          git add .

          imagepath=$(nixos-rebuild build-image --flake .#vm --image-variant qemu --no-link)
          echo "$imagepath"

          mkdir -p ~/.local

          rm -f ~/.local/vm.qcow2
          ln -s "$imagepath" ~/.local/vm.qcow2
        '';
      };
    };
}
