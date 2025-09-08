{ pkgs, ... }:

with pkgs; [
  (sage.override {requireSageTests = false;})
]
