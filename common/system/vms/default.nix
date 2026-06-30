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
          { hostname, chocoPkgs }:
          let
            unattendFiles = {
              "C:\\Windows\\Setup\\Scripts\\Specialize.ps1" = builtins.readFile ./scripts/Specialize.ps1;
              "C:\\Windows\\Setup\\Scripts\\UserOnce.ps1" = builtins.readFile ./scripts/UserOnce.ps1;
              "C:\\Windows\\Setup\\Scripts\\DefaultUser.ps1" = builtins.readFile ./scripts/DefaultUser.ps1;
              "C:\\Windows\\Setup\\Scripts\\FirstLogon.ps1" =
                builtins.replaceStrings
                  [ "@CHOCOPKGS@" ]
                  [
                    (lib.concatStringsSep " " chocoPkgs)
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

                    storage_vol = {
                      pool = "default";
                      volume = "${name}.qcow2";
                    };

                    nvram_path = "/var/lib/libvirt/qemu/nvram/${name}.nvram";

                    install_virtio = true;
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
                          source = {
                            inherit file;
                          };
                          target = {
                            bus = "sata";
                            inherit dev;
                          };
                          readonly = true;
                        })
                        [
                          {
                            file = "${generateUnattendISO {
                              inherit hostname;
                              inherit chocoPkgs;
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
