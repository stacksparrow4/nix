{ lib, config, ... }@inputs:

{
  options = {
    sprrw.sec.windows.rusthound.enable = lib.mkEnableOption "rusthound";
  };

  config = let
    pkgs = import ./pinned-pkgs.nix { system = inputs.pkgs.system; };
  in lib.mkIf config.sprrw.sec.windows.rusthound.enable {
    home.packages = [(
      pkgs.rustPlatform.buildRustPackage (finalAttrs: {
        name = "rusthound-ce";

        nativeBuildInputs = with pkgs; [
          krb5
          pkg-config
        ];

        buildInputs = with pkgs; [
          libkrb5
          pkg-config
        ];

        LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
        BINDGEN_EXTRA_CLANG_ARGS = "-I${pkgs.glibc.dev}/include -I${pkgs.clang}/resource-root/include";

        src = pkgs.fetchFromGitHub {
          owner = "g0h4n";
          repo = "RustHound-CE";
          rev = "44b461390a095da23fc33fc1a6af5497ddf0cbc0";
          hash = "sha256-5oSmChOq5Lk8IlfJevOW3Ix02CK8uaiqPmyGQRn1lAw=";
        };

        cargoHash = "sha256-TrPkWeXwaHuA5aQgeEH8QLOnkdw9/lTpsYbgT1+m5+c=";
      })
    )];
  };
}
