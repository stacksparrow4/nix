{ moduleWithSystem, ... }:

{
  flake.homeModules.ai-pi = moduleWithSystem (
    { self', ... }:
    {
      pkgs,
      config,
      lib,
      ...
    }:
    let
      cfg = config.sprrw.ai.pi;
    in
    {
      options.sprrw.ai.pi = {
        extraModels = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
        };

        execModel = lib.mkOption {
          type = lib.types.str;
        };
      };

      config = {
        home.file.".pi/agent/models.json".text = builtins.toJSON {
          providers = cfg.extraModels;
        };

        systemd.user = lib.mkIf pkgs.stdenv.isLinux {
          services.pi-clean-sessions = {
            Unit.Description = "Clear pi session logs older than 1 week";
            Service = {
              Type = "oneshot";
              ExecStart = "${pkgs.findutils}/bin/find ${config.home.homeDirectory}/.pi/agent/sessions -mindepth 2 -maxdepth 2 -type f -name '*.jsonl' -mtime +7 -delete";
            };
          };

          timers.pi-clean-sessions = {
            Unit.Description = "Clear pi session logs older than 1 week";
            Timer = {
              OnCalendar = "daily";
              Persistent = true;
            };
            Install.WantedBy = [ "timers.target" ];
          };
        };

        home.packages = [
          self'.packages.pi
          (import ./_pi-convert.nix {
            inherit pkgs;
            model = cfg.execModel;
          })
        ]
        ++ (if pkgs.stdenv.hostPlatform.isLinux then (
          let
            execSystemPrompt = { shell, example }: ''
              Provide a ${shell} command in plain text. Do not provide a description. Do not provide code block formatting. Only output the command. If there is a lack of details, provide most logical solution. For example:

              ${example}
            '';
          in
          [
            (import ./_pi-exec.nix {
              inherit pkgs;
              name = "pi-exec";
              model = cfg.execModel;
              system = execSystemPrompt {
                shell = "bash";
                example = ''
                  User: add new user with default password
                  Response: sudo useradd -m newuser && echo "newuser:password | sudo chpasswd
                '';
              };
            })
            (import ./_pi-exec.nix {
              inherit pkgs;
              name = "pi-exec-pwsh";
              model = cfg.execModel;
              system = execSystemPrompt {
                shell = "PowerShell";
                example = ''
                  User: add new user with default password
                  Response: New-LocalUser -Name "NewUser" -Password (ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force) -FullName "New User" -Description "New local user account"
                '';
              };
            })
          ]
        ) else []);
      };
    }
  );
}
