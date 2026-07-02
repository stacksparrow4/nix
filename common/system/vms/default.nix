{
  pkgs,
  inputs,
  lib,
  config,
  ...
}:

{
  imports = [
    inputs.nixvirt.nixosModules.default
  ];

  options.sprrw.vms.enable = lib.mkEnableOption "vms";

  config = lib.mkIf config.sprrw.vms.enable {
    virtualisation.libvirtd.qemu.vhostUserPackages = [ pkgs.virtiofsd ];

    virtualisation.libvirt =
      let
        nixvirtlib = inputs.nixvirt.lib;

        # Mount read only ISOs
        installMode = false;

        winFsp = pkgs.fetchurl {
          url = "https://github.com/winfsp/winfsp/releases/download/v2.1/winfsp-2.1.25156.msi";
          hash = "sha256-Bzpw4A93Qj40vtmLhuYA3vkzk7pYIiBPrFeikyTbn3o=";
        };
        installersIso = pkgs.runCommand "installers.iso" { nativeBuildInputs = [ pkgs.cdrkit ]; } ''
          mkdir -p root
          cp ${winFsp} root/winfsp.msi
          genisoimage -o "$out" -V INSTALLERS -r -J root
        '';
        generateUnattendISO =
          {
            hostname,
            chocoPkgs,
            localIp,
            additionalScripts,
          }:
          let
            unattendFiles = {
              "C:\\Windows\\Setup\\Scripts\\Specialize.ps1" = builtins.readFile ./scripts/Specialize.ps1;
              "C:\\Windows\\Setup\\Scripts\\UserOnce.ps1" = builtins.readFile ./scripts/UserOnce.ps1;
              "C:\\Windows\\Setup\\Scripts\\DefaultUser.ps1" = builtins.readFile ./scripts/DefaultUser.ps1;
              "C:\\Windows\\Setup\\Scripts\\FirstLogon.ps1" =
                builtins.replaceStrings
                  [ "@CHOCOPKGS@" "@IPADDRESS@" "@ADDITIONALSCRIPTS@" ]
                  [
                    (lib.concatStringsSep " " chocoPkgs)
                    localIp
                    additionalScripts
                  ]
                  (builtins.readFile ./scripts/FirstLogon.ps1);
            };
            filesXml = lib.concatStringsSep "\n" (
              lib.mapAttrsToList (
                path: src: "\t\t<File path=\"${lib.escapeXML path}\">\n${lib.escapeXML src}\t\t</File>"
              ) unattendFiles
            );
            autounattendXml = pkgs.writeText "autounattend.xml" (
              builtins.replaceStrings [ "@FILES@" "@COMPUTERNAME@" ] [ filesXml hostname ] (
                builtins.readFile ./autounattend.xml
              )
            );
          in
          pkgs.runCommand "unattend.iso" { nativeBuildInputs = [ pkgs.cdrkit ]; } ''
            mkdir -p root
            cp ${autounattendXml} root/autounattend.xml
            genisoimage -o "$out" -V UNATTEND -r -J root
          '';
        windowsMachines = [
          {
            name = "windows";
            uuid = "e9646d6b-9d04-4d73-ba93-81f2ae2c7c21";
            ram = 16;
            cpu = 8;
            disk = 100;
            hostname = "WIN-PERSONAL";
            localIp = "192.168.122.9";
            chocoPkgs = [
              "vim"
              "Firefox"
              "dnspyex"
              "procexp"
              "x64dbg.portable"
              "visualstudio2022community"
              "windows-sdk-10-version-2004-windbg"
              "notepadplusplus"
            ];
          }
          {
            name = "ad-client";
            uuid = "621ca18f-9cfc-4b95-84b5-f294f2cf0841";
            ram = 12;
            cpu = 4;
            disk = 100;
            hostname = "CLIENT01";
            localIp = "192.168.122.12";
            chocoPkgs = [
              "vim"
              "Firefox"
              "notepadplusplus"
            ];
            additionalScripts = ''
              {
                Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses "192.168.122.10"
              };
              {
                Add-WindowsCapability -Online -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"
              };
            '';
          }
          {
            name = "ad-server";
            uuid = "d76b1393-b374-4972-b7cd-4e2a2f3ef967";
            ram = 12;
            cpu = 4;
            disk = 64;
            hostname = "SRV01";
            localIp = "192.168.122.11";
            chocoPkgs = [
              "vim"
              "Firefox"
              "notepadplusplus"
            ];
            additionalScripts = ''
              {
                Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses "192.168.122.10"
              };
              {
                Import-Module ServerManager;
                Install-WindowsFeature RSAT-AD-PowerShell;
              };
            '';
          }
          {
            name = "ad-dc";
            uuid = "e0c0506d-a656-4dd8-9aca-f98c9bd5b719";
            ram = 12;
            cpu = 4;
            disk = 64;
            hostname = "DC01";
            localIp = "192.168.122.10";
            chocoPkgs = [
              "vim"
              "Firefox"
              "notepadplusplus"
            ];
          }
        ];
      in
      {
        enable = true;
        swtpm.enable = true;

        connections."qemu:///system" = {
          networks = [
            {
              definition = nixvirtlib.network.writeXML (
                nixvirtlib.network.templates.bridge {
                  name = "default";
                  uuid = "9cd06e90-9133-4236-80fd-5eb2e828cace";
                  subnet_byte = 122;
                }
              );

              active = true;
            }
          ];

          pools = [
            {
              definition = nixvirtlib.pool.writeXML {
                name = "default";
                uuid = "2fd40bef-8144-42c4-a7df-6a859428105c";
                type = "dir";
                target = {
                  path = "/var/lib/libvirt/images";
                };
              };

              active = true;

              volumes = map (
                { name, disk, ... }:
                {
                  present = true;
                  definition = nixvirtlib.volume.writeXML {
                    name = "${name}.qcow2";
                    capacity = {
                      count = disk;
                      unit = "GiB";
                    };
                    target.format.type = "qcow2";
                  };
                }
              ) windowsMachines;
            }
          ];

          domains = map (
            {
              name,
              uuid,
              ram,
              cpu,
              hostname,
              chocoPkgs,
              localIp,
              additionalScripts ? "",
              ...
            }:
            {
              definition = nixvirtlib.domain.writeXML (
                let
                  templateConfig = nixvirtlib.domain.templates.windows {
                    inherit name;
                    inherit uuid;

                    memory = {
                      count = ram;
                      unit = "GiB";
                    };
                    vcpu = {
                      count = cpu;
                    };

                    storage_vol = "/var/lib/libvirt/images/${name}.qcow2";

                    nvram_path = "/var/lib/libvirt/qemu/nvram/${name}.nvram";

                    install_virtio = false; # Done manually below so that it creates an empty disk if installMode is false
                    virtio_net = true;
                    virtio_drive = true;
                    virtio_video = false; # Don't use GPU
                  };
                in
                templateConfig
                // {
                  devices = templateConfig.devices // {
                    disk =
                      templateConfig.devices.disk
                      ++ (map
                        ({ file, dev }: {
                          type = "file";
                          device = "cdrom";
                          driver = {
                            name = "qemu";
                            type = "raw";
                          };
                          source = if installMode then { inherit file; } else null;
                          target = {
                            bus = "sata";
                            inherit dev;
                          };
                          readonly = true;
                        })
                        [
                          {
                            file = "${nixvirtlib.guest-install.virtio-win.iso}";
                            dev = "hdd";
                          }
                          {
                            file = "${generateUnattendISO {
                              inherit
                                hostname
                                chocoPkgs
                                localIp
                                additionalScripts
                                ;
                            }}";
                            dev = "hde";
                          }
                          {
                            file = "${installersIso}";
                            dev = "hdf";
                          }
                        ]
                      );

                    filesystem = [
                      {
                        type = "mount";
                        accessmode = "passthrough";
                        driver = {
                          type = "virtiofs";
                        };
                        source = {
                          dir = "/home/sprrw/shared";
                        };
                        target = {
                          dir = "shared";
                        };
                      }
                    ];
                  };

                  memoryBacking = {
                    source = {
                      type = "memfd";
                    };
                    access = {
                      mode = "shared";
                    };
                  };
                }
              );
            }
          ) windowsMachines;
        };
      };
  };
}
