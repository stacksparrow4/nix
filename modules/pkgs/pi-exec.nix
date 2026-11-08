{
  perSystem =
    {
      pkgs,
      self',
      ...
    }:
    {
      packages.pi-exec = pkgs.writeShellApplication {
        name = "pi-exec";
        text =
          let
            systemFile = pkgs.writeText "exec-system" ''
              Provide a bash command in plain text. Do not provide a description. Do not provide code block formatting. Only output the command. If there is a lack of details, provide most logical solution. For example:

              User: add new user with default password
              Response: sudo useradd -m newuser && echo "newuser:password | sudo chpasswd
            '';
          in
          ''
            ${self'.packages.pi}/bin/pi --system "$(cat ${systemFile})" -p --no-tools --no-extensions -- --thinking off "$@" | sed -rz 's/^\n+//; s/\n+$/\n/g'
          '';
      };
    };
}
