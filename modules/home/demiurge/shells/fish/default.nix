{
  pkgs,
  lib,
  ...
}: {
  xdg.configFile."fish/themes/Catppuccin Mocha.theme".source = ./catppuccin.theme;

  programs.fish = {
    enable = true;
    shellAliases = let
      inherit (lib) getExe;
    in
      with pkgs; {
        ls = "${getExe eza} --icons";
        ll = "${getExe eza} --icons -l";
        la = "${getExe eza} --icons -la";
        grep = "${getExe ripgrep}";
        cat = "${getExe bat}";
        ccat = "cat";
        run = "nix run";
        v = "nvim";
        vim = "nvim";
        temp = "cd $(mktemp -d)";
        fcd = "cd $(${getExe fd} -tdirectory | ${getExe fzf})";
        update = "nix flake update $FLAKE && nh os switch";
        ":q" = "exit";
        subs = "ytfzf -t -T iterm2 -c SI --sort";
      };
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

    shellInit =
      /*
      fish
      */
      ''
        set fish_greeting ""
        fish_config theme choose "Catppuccin Mocha"
      '';
  };

  # Some dependencies
  home.packages = with pkgs.unstable; [
    sqlite # For fzf
    fzf
  ];
}
