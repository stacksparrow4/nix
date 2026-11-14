{ config, ... }:

{
  flake.modules.homeManager.programming = {
    imports = with config.flake.modules.homeManager; [
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
      python

      (
        { pkgs, ... }:
        {
          home.packages = with pkgs; [
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
