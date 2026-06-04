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
  # hostForward applies only if network = false. Structure: { host = "..."; model = "model"; context = ...; }
  hostForward ? null,
  extraMounts ? [ ],
}:

assert !(network && hostForward != null); # can't have network = true and hostForward != null
let
  pi = import ../../../../pkgs/pi { inherit pkgs; };

  localModelName = "local";

  createExtensionMount = extname: {
    hostPath = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/common/home/ai/pi/extensions/${extname}";
    boxPath = "/home/sprrw/.pi/agent/extensions/${extname}";
    ro = true;
    type = "file";
  };
  braveSearchExtensions = if braveSearch then [ "brave-search.ts" ] else [ ];
  allExtensions = extensions ++ braveSearchExtensions;
  allTools = tools ++ (if braveSearch then [ "web_search" ] else [ ]);
in
mkSandbox {
  inherit name;
  sharedPaths =
    (builtins.map createExtensionMount allExtensions)
    ++ [
      {
        hostPath = "$HOME/.pi/agent/settings.json";
        boxPath = "/home/sprrw/.pi/agent/settings.json";
        ro = false;
        type = "file";
      }
      {
        hostPath = "$HOME/.pi/agent/sessions";
        boxPath = "/home/sprrw/.pi/agent/sessions";
        ro = false;
        type = "dir";
      }
      {
        hostPath = pkgs.writeText "pi-models" (
          builtins.toJSON {
            providers =
              (
                if config.sprrw.ai.llama-cpp.enable then
                  {
                    local-llama = {
                      baseUrl = "http://localhost:8033/v1";
                      api = "openai-completions";
                      apiKey = "llama";
                      models = [
                        (
                          if hostForward != null then
                            {
                              id = hostForward.model;
                              contextWindow = hostForward.context;
                            }
                          else
                            {
                              id = localModelName;
                              contextWindow = config.sprrw.ai.llama-cpp.context;
                            }
                        )
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
      {
        hostPath = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/common/home/ai/pi/skills";
        boxPath = "/home/sprrw/.pi/agent/skills";
        ro = true;
        type = "dir";
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
            hostPath = if hostForward != null then "$SOCAT_DIR" else "/tmp/llama-cpp";
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
  inherit shareCwd network;
  outsideBeforeScript =
    if hostForward != null then
      ''
        SOCAT_DIR=$(mktemp -d)

        socat UNIX-LISTEN:"$SOCAT_DIR"/llama.sock,fork OPENSSL:${hostForward.host}:443 &>/dev/null &
        SOCAT_PID=$!

        trap 'rm -rf $SOCAT_DIR 2>/dev/null; kill $SOCAT_PID 2>/dev/null; wait $SOCAT_PID 2>/dev/null' EXIT
      ''
    else
      "";
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
            if (builtins.length allTools) > 0 then "--tools ${builtins.concatStringsSep "," allTools}" else ""
          } \
          ${
            if network then
              ""
            else
              "--models ${if hostForward != null then hostForward.model else localModelName}"
          } \
          "$@"
      '';
    }
  }/bin/pi";
  roDotGit = shareCwd;
}
