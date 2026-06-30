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

              volumes = [
                {
                  present = true;
                  definition = nixvirtlib.volume.writeXML {
                    name = "windows.qcow2";
                    capacity = {
                      count = 100;
                      unit = "GiB";
                    };
                    target.format.type = "qcow2";
                  };
                }
              ];
            }
          ];

          domains = [
            {
              definition = nixvirtlib.domain.writeXML (
                let
                  templateConfig = nixvirtlib.domain.templates.windows {
                    name = "windows";
                    uuid = "e9646d6b-9d04-4d73-ba93-81f2ae2c7c21";
                    memory = {
                      count = 16;
                      unit = "GiB";
                    };
                    vcpu = {
                      count = 8;
                    };

                    storage_vol = {
                      pool = "default";
                      volume = "windows.qcow2";
                    };

                    nvram_path = "/var/lib/libvirt/qemu/nvram/windows.nvram";

                    install_virtio = true;
                    virtio_net = true;
                    virtio_drive = true;
                    virtio_video = false; # Don't use GPU
                  };
                  winFsp = pkgs.fetchurl {
                    url = "https://github.com/winfsp/winfsp/releases/download/v2.1/winfsp-2.1.25156.msi";
                    hash = "sha256-Bzpw4A93Qj40vtmLhuYA3vkzk7pYIiBPrFeikyTbn3o=";
                  };
                  sprrwIso = pkgs.runCommand "sprrw-vm.iso" { nativeBuildInputs = [ pkgs.cdrkit ]; } ''
                    mkdir -p root
                    cp ${./autounattend.xml} root/autounattend.xml
                    cp ${winFsp} root/winfsp.msi
                    genisoimage -o "$out" -V SPRRW -r -J root
                  '';
                in
                templateConfig
                // {
                  devices = templateConfig.devices // {
                    disk = templateConfig.devices.disk ++ [
                      {
                        type = "file";
                        device = "cdrom";
                        driver = {
                          name = "qemu";
                          type = "raw";
                        };
                        source = {
                          file = "${sprrwIso}";
                        };
                        target = {
                          bus = "sata";
                          dev = "hde";
                        };
                        readonly = true;
                      }
                    ];

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
          ];
        };
      };
  };
}
