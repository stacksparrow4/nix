# metasm_shell, derived from metasploit's pattern_create script.
{
  perSystem =
    { pkgs, ... }:
    {
      packages.msfscripts = pkgs.runCommand "msfscripts" { } ''
        mkdir -p $out/bin
        cp ${pkgs.metasploit}/bin/msf-pattern_create $out/bin/metasm_shell
        sed -i 's/pattern_create\.rb/metasm_shell.rb/' $out/bin/metasm_shell
      '';
    };
}
