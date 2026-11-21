{
  perSystem =
    { pkgs, self', ... }:
    {
      packages = {
        yazi-file-picker = pkgs.writeShellApplication {
          name = "yazi-file-picker";

          runtimeInputs = [
            self'.packages.foot
            self'.packages.yazi
          ];

          text = builtins.readFile ./yazi-file-picker.sh;
        };
      };
    };
}
