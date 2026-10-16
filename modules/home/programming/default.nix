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
      node
      php
      ruby
      rust
      typst
      xml
      zig
      dafny
    ];
  };
}
