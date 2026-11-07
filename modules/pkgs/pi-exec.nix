{
  perSystem =
    {
      pkgs,
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
            output=$(pi --system "$(cat ${systemFile})" -p --no-tools --no-extensions -- --thinking off "$@" | sed -rz 's/^\n+//; s/\n+$/\n/g')
            echo "$output"
            printf "\n\e[33m[e]\e[0m exec  \e[33m[c]\e[0m copy: "
            read -r choice
            case "$choice" in
              e)
                eval "$output"
                ;;
              c)
                echo -n "$output" | ${pkgs.wl-clipboard}/bin/wl-copy
                printf "\e[32mCopied to clipboard\e[0m\n"
                ;;
              *)
                printf "\e[31mAborted\e[0m\n"
                ;;
            esac
          '';
      };
    };
}
