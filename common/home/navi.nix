{ pkgs, config, ... }:

{
  home.packages = with pkgs; [ navi ];

  home.file.".local/share/navi".source = ./dotfiles/navi;
}
