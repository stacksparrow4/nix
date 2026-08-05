{
  flake.homeModules.programming-c =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        gcc
        gnumake
        clang-tools
        cmake
        cmake-language-server
        pkg-config
        nasm
        ninja
      ];
    };
}
