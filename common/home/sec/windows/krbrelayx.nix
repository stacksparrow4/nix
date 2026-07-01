{
  pkgs,
  lib,
  config,
  ...
}:

{
  options = {
    sprrw.sec.windows.krbrelayx.enable = lib.mkEnableOption "krbrelayx";
  };

  config = lib.mkIf config.sprrw.sec.windows.krbrelayx.enable {
    home.packages = [
      (pkgs.stdenv.mkDerivation {
        name = "krbrelayx";

        src = pkgs.fetchFromGitHub {
          owner = "dirkjanm";
          repo = "krbrelayx";
          rev = "10b45a33bc4361ec4a5546eea62db2e4244d3255";
          hash = "sha256-NnC14jVkWPhEtoGicTFMAef1/kHt8wZr6+Am4NQ4nUg=";
        };

        pythonWithPkgs = pkgs.python3.withPackages (
          ps: with ps; [
            impacket
            ldap3
            dnspython
          ]
        );

        buildPhase = ''
          mkdir -p $out/bin

          for script in $src/*.py; do
            outpath="$out/bin/$(basename -s .py "$script")"
            echo "#!${pkgs.stdenv.shell}" > "$outpath"
            echo "$pythonWithPkgs/bin/python3 $script \"\$@\"" >> "$outpath"

            chmod +x "$outpath"
          done
        '';

        dontInstall = true;
      })
    ];
  };
}
