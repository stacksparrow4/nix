{
  pkgs,
  config,
  lib,
  mkSandbox,
  ...
}:

{
  options = {
    sprrw.sec.windows.impacket.enable = lib.mkEnableOption "gcc";
  };

  config = lib.mkIf config.sprrw.sec.windows.impacket.enable {
    home.packages =
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
        impacketScripts = [
          "addcomputer.py"
          "atexec.py"
          "changepasswd.py"
          "dacledit.py"
          "dcomexec.py"
          "describeTicket.py"
          "dpapi.py"
          "DumpNTLMInfo.py"
          "esentutl.py"
          "exchanger.py"
          "findDelegation.py"
          "GetADComputers.py"
          "GetADUsers.py"
          "getArch.py"
          "Get-GPPPassword.py"
          "GetLAPSPassword.py"
          "GetNPUsers.py"
          "getPac.py"
          "getST.py"
          "getTGT.py"
          "GetUserSPNs.py"
          "goldenPac.py"
          "karmaSMB.py"
          "keylistattack.py"
          "kintercept.py"
          "lookupsid.py"
          "machine_role.py"
          "mimikatz.py"
          "mqtt_check.py"
          "mssqlclient.py"
          "mssqlinstance.py"
          "net.py"
          "netview.py"
          "ntfs-read.py"
          "ntlmrelayx.py"
          "owneredit.py"
          "ping6.py"
          "ping.py"
          "psexec.py"
          "raiseChild.py"
          "rbcd.py"
          "rdp_check.py"
          "registry-read.py"
          "reg.py"
          "rpcdump.py"
          "rpcmap.py"
          "sambaPipe.py"
          "samrdump.py"
          "secretsdump.py"
          "services.py"
          "smbclient.py"
          "smbexec.py"
          "smbserver.py"
          "sniffer.py"
          "sniff.py"
          "split.py"
          "ticketConverter.py"
          "ticketer.py"
          "tstool.py"
          "wmiexec.py"
          "wmipersist.py"
          "wmiquery.py"
        ];
        fixedImpacket = pkgs.runCommand "fixed-impacket" { } ''
          mkdir -p "$out/bin"

          for binfile in $(cd ${pkgs.python312Packages.impacket}/bin; echo *); do
            cat > "$out/bin/$binfile" << EOF
          #!${pkgs.stdenv.shell}

          source ${impacketEnv}

          $binfile "\$@"
          EOF
            chmod +x "$out/bin/$binfile"
          done
        '';
      in
      map (
        scriptName:
        (mkSandbox {
          name = scriptName;
          shareCwd = true;
          network = true;
          prog = "${fixedImpacket}/bin/${scriptName}";
        })
      ) impacketScripts;
  };
}
