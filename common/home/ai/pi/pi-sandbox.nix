{
  pkgs,
  config,
  mkSandbox,
  extraModels,
  name,
  tools ? [
    "read"
    "write"
    "edit"
    "bash"
  ],
  extensions,
  system,
  braveSearch ? false,
  # Settings are locked down by defualt
  shareCwd ? false,
  network ? false,
  extraMounts ? [ ],
}:

let
  pi = import ../../../../pkgs/pi { inherit pkgs; };

  createExtensionMount = extname: {
    hostPath = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/common/home/ai/pi/extensions/${extname}";
    boxPath = "/home/sprrw/.pi/agent/extensions/${extname}";
    ro = true;
    type = "file";
  };
in
mkSandbox {
  inherit name;
  sharedPaths =
    (builtins.map createExtensionMount extensions)
    ++ [
      {
        hostPath = "$HOME/.pi/agent/settings.json";
        boxPath = "/home/sprrw/.pi/agent/settings.json";
        ro = false;
        type = "file";
      }
      {
        hostPath = pkgs.writeText "pi-models" (
          builtins.toJSON {
            providers =
              (
                if config.sprrw.ai.llama-cpp.enable then
                  {
                    llama = {
                      baseUrl = "http://localhost:8033/v1";
                      api = "openai-completions";
                      apiKey = "llama";
                      models = [
                        {
                          id = "llama";
                          contextWindow = config.sprrw.ai.llama-cpp.context;
                        }
                      ];
                    };
                  }
                else
                  { }
              )
              // extraModels;
          }
        );
        boxPath = "/home/sprrw/.pi/agent/models.json";
        ro = true;
        type = "file";
      }
      {
        hostPath = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/common/home/ai/pi/${system}";
        boxPath = "/home/sprrw/.pi/agent/SYSTEM.md";
        ro = true;
        type = "file";
      }
    ]
    ++ (
      if network then
        [
          {
            hostPath = "$HOME/.pi/agent/auth.json";
            boxPath = "/home/sprrw/.pi/agent/auth.json";
            ro = false;
            type = "file";
          }
        ]
      else
        [
          {
            hostPath = "/tmp/llama-cpp";
            boxPath = "/tmp/llama-cpp";
            ro = true;
            type = "dir";
          }
        ]
    )
    ++ (
      if braveSearch then
        [
          {
            hostPath = "$HOME/.config/brave-search";
            boxPath = "/home/sprrw/.config/brave-search";
            ro = true;
            type = "dir";
          }
        ]
      else
        [ ]
    )
    ++ extraMounts;
  downgradeTerm = true;
  stdin = true;
  tty = true;
  inherit shareCwd network;
  hostNetwork = network;
  prog = "${
    pkgs.writeShellApplication {
      name = "pi";
      text = ''
        ${
          if network then
            ""
          else
            "socat TCP-LISTEN:8033,reuseaddr,fork UNIX-CONNECT:/tmp/llama-cpp/llama.sock &"
        }

        ${pi}/bin/pi \
          --no-tools ${
            if (builtins.length tools) > 0 then "--tools ${builtins.concatStringsSep "," tools}" else ""
          } \
          ${if network then "" else "--models llama"} \
          "$@"
      '';
    }
  }/bin/pi";
  roDotGit = shareCwd;
}
