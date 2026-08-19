{
  perSystem =
    { pkgs, ... }:
    let
      sprrw-unwrapped = (import ./_Cargo.nix { inherit pkgs; }).rootCrate.build;
    in
    {
      packages.sprrw = pkgs.stdenv.mkDerivation {
        pname = "sprrw";
        inherit (sprrw-unwrapped) version;

        dontUnpack = true;

        nativeBuildInputs = [ pkgs.installShellFiles ];

        installPhase = ''
          runHook preInstall

          mkdir -p $out/bin
          cp ${sprrw-unwrapped}/bin/sprrw $out/bin/sprrw

          installShellCompletion --cmd sprrw \
            --bash <($out/bin/sprrw completions bash) \
            --zsh <($out/bin/sprrw completions zsh) \
            --fish <($out/bin/sprrw completions fish)

          runHook postInstall
        '';
      };
    };
}
