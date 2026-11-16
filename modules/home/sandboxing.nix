{ moduleWithSystem, ... }:

{
  flake.modules.homeManager.sandbox = moduleWithSystem (
    { self', ... }:
    { pkgs, config, ... }:
    {
      home.packages = with self'.packages; [
        box
        (pkgs.writeShellApplication {
          name = "build-vm";
          text = ''
            cd ${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}
            git add .

            imagepath=$(nixos-rebuild build-image --flake .#vm --image-variant qemu --no-link)
            echo "$imagepath"

            mkdir -p ~/.local

            rm -f ~/.local/vm.qcow2
            ln -s "$imagepath" ~/.local/vm.qcow2

            sudo ln -sfn "$HOME/.local/vm.qcow2" /nix/var/nix/gcroots/vm.qcow2
          '';
        })
      ];

      sprrw.term.shellExtra = ''
        alias b='box'
        alias bc='box --cwd'
      '';
    }
  );
}
