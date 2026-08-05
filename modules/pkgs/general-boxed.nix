{
  perSystem =
    {
      pkgs,
      lib,
      mkSandbox,
      ...
    }:
    {
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        nodemon = mkSandbox {
          name = "nodemon";
          shareCwd = true;
          network = true;
          prog = "${pkgs.nodemon}/bin/nodemon";
        };

        dumbpipe = mkSandbox {
          name = "dumbpipe";
          network = true;
          prog = "${pkgs.dumbpipe}/bin/dumbpipe";
        };
      };
    };
}
