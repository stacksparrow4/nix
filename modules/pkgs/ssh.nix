{
  perSystem =
    { pkgs, ... }:
    {
      packages.ssh = pkgs.writeShellApplication {
        name = "ssh";
        text = ''
          export TERM=xterm-256color

          ${pkgs.openssh}/bin/ssh -o WarnWeakCrypto=no "$@"
        '';
      };
    };
}
