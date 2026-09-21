{ inputs, ... }:

{
  perSystem =
    { pkgs, ... }:
    let
      sprrw-unwrapped =
        ((inputs.crate2nix.lib.tools { inherit pkgs; }).appliedCargoNix {
          name = "sprrw";
          src = ./.;
        }).rootCrate.build;

      notifier =
        if pkgs.stdenv.isDarwin then pkgs.terminal-notifier else pkgs.libnotify;
    in
    {
      packages.sprrw = pkgs.stdenv.mkDerivation {
        pname = "sprrw";
        inherit (sprrw-unwrapped) version;

        dontUnpack = true;

        nativeBuildInputs = [
          pkgs.installShellFiles
          pkgs.makeWrapper
        ];

        installPhase = ''
          runHook preInstall

          mkdir -p $out/bin
          cp ${sprrw-unwrapped}/bin/sprrw $out/bin/sprrw

          wrapProgram $out/bin/sprrw \
            --prefix PATH : ${pkgs.lib.makeBinPath [ notifier ]}

          installShellCompletion --cmd sprrw \
            --bash <($out/bin/sprrw completions bash) \
            --zsh <($out/bin/sprrw completions zsh) \
            --fish <($out/bin/sprrw completions fish)

          runHook postInstall
        '';
      };
    };
}
