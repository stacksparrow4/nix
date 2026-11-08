{
  flake.modules.homeManager.inputrc = {
    programs.readline = {
      enable = true;
      variables = {
        editing-mode = "vi";
        keyseq-timeout = 10;
        show-mode-in-prompt = true;
      };
      extraConfig = ''
        set vi-ins-mode-string \1\e[6 q\2
        set vi-cmd-mode-string \1\e[2 q\2

        set keymap vi-insert
        "\C-p": previous-history
        "\C-n": next-history
        "\C-l": clear-screen
        "\e.": yank-last-arg
      '';
    };
  };
}
