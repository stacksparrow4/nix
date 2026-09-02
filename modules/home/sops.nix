{
  flake.homeModules.sops =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      options.sprrw.sops.opRef = lib.mkOption {
        type = lib.types.str;
      };

      config = {
        home.packages = [
          (pkgs.symlinkJoin {
            name = "sops";
            paths = [ pkgs.sops ];
            nativeBuildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/sops \
                --set SOPS_AGE_SSH_PRIVATE_KEY_CMD ${lib.escapeShellArg "op read ${lib.escapeShellArg config.sprrw.sops.opRef}"}
            '';
          })
        ];
      };
    };
}
