{ config, lib, ... }@inputs:

{
  options = {
    sprrw.sec.windows.impacket.enable = lib.mkEnableOption "gcc";
  };

  config = let
    pkgs = import ./pinned-pkgs.nix { system = inputs.pkgs.system; };
  in lib.mkIf config.sprrw.sec.windows.impacket.enable {
    home.packages = [(
      let
        impacketEnv = pkgs.stdenv.mkDerivation {
          name = "win-impacket-env";
          buildInputs = with pkgs.python312Packages; [
            impacket
            pycryptodome
          ];
          phases = [ "buildPhase" ];
          buildPhase = ''
            export >> "$out"
          '';
        };
      in
        pkgs.runCommand "fixed-impacket" {} ''
          mkdir -p "$out/bin"

          for binfile in $(cd ${pkgs.python312Packages.impacket}/bin; echo *); do
            cat > "$out/bin/$binfile" << EOF
          #!${pkgs.stdenv.shell}

          source ${impacketEnv}

          $binfile "\$@"
          EOF
            chmod +x "$out/bin/$binfile"
          done
        ''
    )];
  };
}
