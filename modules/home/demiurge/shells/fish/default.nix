{
  pkgs,
  lib,
  ...
}: let
  eza = lib.getExe pkgs.eza;
in {
  programs.fish = {
    enable = true;
    plugins = [
      {
        name = "fzf";
        src = pkgs.fetchFromGitHub {
          owner = "PatrickF1";
          repo = "fzf.fish";
          rev = "bbaf29ae8ad30e1cb1c78d2c14814b1678022875";
          sha256 = "sha256-6ebzDQkpJNq7ZEmDeheek/OfMgbYH4wU3tf1QGgZr40=";
        };
      }
      {
        name = "autopair";
        src = pkgs.fetchFromGitHub {
          owner = "jorgebucaran";
          repo = "autopair.fish";
          rev = "4d1752ff5b39819ab58d7337c69220342e9de0e2";
          sha256 = "sha256-qt3t1iKRRNuiLWiVoiAYOu+9E7jsyECyIqZJ/oRIT1A=";
        };
      }
      {
        name = "z";
        src = pkgs.fetchFromGitHub {
          owner = "jethrokuan";
          repo = "z";
          rev = "85f863f20f24faf675827fb00f3a4e15c7838d76";
          sha256 = "sha256-+FUBM7CodtZrYKqU542fQD+ZDGrd2438trKM0tIESs0=";
        };
      }
    ];
    shellAliases = {
      ls = "${eza} --icons";
      ll = "${eza} --icons -l";
      la = "${eza} --icons -la";
      gc = "git commit -am";
      ga = "git add -A";
      cat = "bat";
      ccat = "cat";
    };

    shellInit =
      /*
      fish
      */
      ''
        set fish_greeting ""
      '';

    interactiveShellInit =
      /*
      fish
      */
      ''
        set -g theme_display_vi yes
        set -g theme_display_nix yes

         # Catppuccin color palette

        # --> special
        set -l foreground ffffff
        set -l selection 313244

        # --> palette
        set -l teal 94e2d5
        set -l flamingo f2cdcd
        set -l mauve cba6f7
        set -l pink f5c2e7
        set -l red f38ba8
        set -l peach fab387
        set -l green a6e3a1
        set -l yellow f9e2af
        set -l blue 89b4fa
        set -l gray 6c7086

        # Syntax Highlighting
        set -g fish_color_normal $foreground
        set -g fish_color_command $green
        set -g fish_color_param $foreground
        set -g fish_color_keyword $red
        set -g fish_color_quote $blue
        set -g fish_color_redirection $pink
        set -g fish_color_end $peach
        set -g fish_color_error $red
        set -g fish_color_gray $gray
        set -g fish_color_selection --background=$selection
        set -g fish_color_search_match --background=$selection
        set -g fish_color_operator $pink
        set -g fish_color_escape $flamingo
        set -g fish_color_autosuggestion $gray
        set -g fish_color_cancel $red

        # Prompt
        set -g fish_color_cwd $yellow
        set -g fish_color_user $teal
        set -g fish_color_host $blue

        # Completion Pager
        set -g fish_pager_color_progress $gray
        set -g fish_pager_color_prefix $pink
        set -g fish_pager_color_completion $foreground
        set -g fish_pager_color_description $gray
      '';
  };

  # Some dependencies
  home.packages = with pkgs.unstable; [
    sqlite # For fzf
    fzf
  ];
}
