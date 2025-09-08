{ pkgs, ... }:

[(
let
  src = pkgs.fetchFromGitHub {
    owner = "Tib3rius";
    repo = "AutoRecon";
    rev = "fd87c99abc5ef8534f6caba2f3b2309308f5e962";
    hash = "sha256-4yerINhRHINL8oDjF0ES72QrO0DLK6C5Y0wJ913Nozg=";
  };
  py = pkgs.python312.withPackages (ppkgs: with ppkgs; [
    colorama
    impacket
    platformdirs
    psutil
    requests
    toml
    unidecode
  ]);
  buildInps = with pkgs; [
    curl
    dnsrecon
    enum4linux
    feroxbuster
    gobuster
    nbtscan
    nikto
    nmap
    onesixtyone
    samba
    sslscan
    whatweb
  ];
in
pkgs.writeShellScriptBin "autorecon" ''
  export PATH=${pkgs.lib.makeBinPath buildInps}:$PATH
  ${py}/bin/python3 ${src}/autorecon.py "$@"
''
)]
