{ config, ... }:

{
  flake.homeModules.programming = {
    imports = with config.flake.homeModules; [
      c
      databases
      dotnet
      git
      go
      java
      kubernetes
      lua
      rust
      zig

      (
        { pkgs, ... }:
        {
          home.packages = with pkgs; [
            dafny
            lemminx
            nodejs_22
            php
            ruby
            typst
          ];
        }
      )
    ];
  };
}
