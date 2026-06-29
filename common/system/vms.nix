{
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

              volumes = [{
                present = true;
                definition = nixvirtlib.volume.writeXML {
                  name = "windows.qcow2";
                  capacity = {
                    count = 100;
                    unit = "GiB";
                  };
                  target.format.type = "qcow2";
                };
              }];
            }
          ];

          domains = [
            {
              definition = nixvirtlib.domain.writeXML (nixvirtlib.domain.templates.windows {
                name = "windows";
                uuid = "e9646d6b-9d04-4d73-ba93-81f2ae2c7c21";
                memory = { count = 16; unit = "GiB"; };
                vcpu = { count = 8; };

                storage_vol = {
                  pool = "default";
                  volume = "windows.qcow2";
                };

                nvram_path = "/var/lib/libvirt/qemu/nvram/windows.nvram";

                install_virtio = true;
                virtio_net = true;
                virtio_drive = true;
                virtio_video = false;
              });
            }
          ];
        };
      };
  };
}
