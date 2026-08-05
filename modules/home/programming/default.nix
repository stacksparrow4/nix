# Aggregate of the language toolchains every dev host wants. `programming-sage`
# is not in here: it is a heavy, rarely-used build, imported explicitly by
# nest01.
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
