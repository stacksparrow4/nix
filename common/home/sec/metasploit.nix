{ config, lib, pkgs, ... }:

{
  options = {
    sprrw.sec.metasploit.enable = lib.mkEnableOption "metasploit";
  };

  config = lib.mkIf config.sprrw.sec.metasploit.enable {
    home.packages = with pkgs; [
      metasploit
      (
        runCommand "msfscripts" {} ''
          mkdir -p $out/bin
          cp ${metasploit}/bin/msf-pattern_create $out/bin/metasm_shell
          sed -i 's/pattern_create\.rb/metasm_shell.rb/' $out/bin/metasm_shell
        ''
      )
    ];
  };
}
