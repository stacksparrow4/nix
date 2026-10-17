{ moduleWithSystem, ... }:

{
  flake.homeModules.pi = moduleWithSystem (
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
        models = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { providers = {}; };
        };
      };

      config = {
        home.file.".pi/agent/models.json".text = builtins.toJSON cfg.models;

        # Remove when upstrema
        sprrw.ai.pi.models.providers.openrouter.models = [
          {
            id = "deepseek/deepseek-v4.1-flash-1017";
            name = "DeepSeek: DeepSeek V4.1 Flash 1017";
            reasoning = true;
            thinkingLevelMap = {
              off = "none";
              minimal = null;
              low = "low";
              medium = null;
              high = "high";
              xhigh = null;
              max = "max";
            };
            input = [
              "text"
              "image"
            ];
            cost = {
              input = 0.15;
              output = 0.6;
              cacheRead = 0.003;
              cacheWrite = 0;
            };
            contextWindow = 1048576;
            maxTokens = 393216;
          }
        ];

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
