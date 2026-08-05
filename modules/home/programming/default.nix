{ config, ... }:

{
  flake.homeModules.programming = {
    imports = with config.flake.homeModules; [
      programming-c
      programming-databases
      programming-dotnet
      programming-git
      programming-go
      programming-java
      programming-kubernetes
      programming-lua
      programming-node
      programming-php
      programming-ruby
      programming-rust
      programming-typst
      programming-xml
      programming-zig
    ];
  };
}
