{ ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      packages.llama-server =
        let
          llama-server =
            (pkgs.callPackage ./_Cargo.nix { }).rootCrate.build;
        in
        pkgs.runCommand "llama-server" { nativeBuildInputs = [ pkgs.installShellFiles ]; } ''
          mkdir -p $out/bin
          ln -s ${llama-server}/bin/llama-server $out/bin/llama-server
          installShellCompletion --cmd llama-server \
            --bash <(${llama-server}/bin/llama-server --completions bash) \
            --zsh <(${llama-server}/bin/llama-server --completions zsh) \
            --fish <(${llama-server}/bin/llama-server --completions fish)
        '';
    };
}
