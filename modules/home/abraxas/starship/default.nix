{config, ...}: {
  home = {
    sessionVariables = {
      STARSHIP_CACHE = "${config.xdg.cacheHome}/starship";
    };
  };

  programs.starship = {
    enable = true;
    enableTransience = true;

    settings = {
      add_newline = true;

      character = {
        error_symbol = "[┃](bright-red)";
        success_symbol = "[┃](green)";
      };

      cmd_duration = {
        disabled = false;
        format = "[ $duration]($style)";
        min_time = 100;
        style = "fg:yellow";
      };

      directory = {
        disabled = false;
        format = "[](fg:surface0)[ ](fg:blue bg:surface0 bold)[](fg:surface0 bg:mantle)[$read_only]($read_only_style)[$repo_root]($repo_root_style)[ $path]($style)[](fg:mantle)";
        read_only = " ";
        read_only_style = "fg:#ffffff bg:mantle";
        repo_root_format = "[](fg:surface0)[ ](fg:blue bg:surface0 bold)[](bg:mantle fg:surface0)[$read_only]($read_only_style)[$before_root_path]($before_repo_root_style)[$repo_root]($repo_root_style)[$path]($style)[](fg:mantle)[ ]()";
        repo_root_style = "fg:#ffffff bold bg:mantle";
        style = "fg:#ffffff bold bg:mantle";
        truncate_to_repo = true;
        truncation_length = 3;
        truncation_symbol = "…/";
        use_os_path_sep = true;
      };

      fill = {
        style = "fg:#505050";
        symbol = "─";
      };

      format = ''
        $character $shell $directory $username $hostname $git_branch $git_status $git_commit $fill
        $character [❯](red)[❯](yellow)[❯ ](green)
      '';
      right_format = "\n$cmd_duration\n";

      git_branch = {
        format = "on branch [](fg:surface0)[$symbol](bg:surface0 fg:mauve)[](fg:surface0 bg:mantle)[ $branch]($style)[](fg:mantle) ";
        style = "bold fg:#ffffff bg:mantle";
        symbol = "";
      };

      git_status = {
        ahead = "[﯁ ](fg:blue bg:mantle)[$count](fg:white bg:mantle bold) ";
        behind = "[﮾ ](fg:peach bg:mantle white)[$count](fg:white bg:mantle bold) ";
        conflicted = " [$count](fg:#ffffff bg:mantle bold) ";
        deleted = "[ ](bg:mantle fg:red)[$count](fg:white bg:mantle bold) ";
        diverged = "[ ](fg:purple bg:mantle)|[ ﯁ ](bright-blue)[$ahead_count](fg:white bg:mantle bold)[ ﮾ ](white)[$behind_count](bright-white) ";
        format = "with [](fg:surface0)[󱖫](bg:surface0 fg:#ffffff bold)[](bg:mantle fg:surface0)[ $all_status$ahead_behind]($style)[](fg:mantle)";
        modified = "[ ](bg:mantle fg:blue)[$count](fg:white bg:mantle bold) ";
        renamed = "[ ](bg:mantle fg:bright-cyan)[$count](fg:white bg:mantle bold) ";
        staged = "[ ](bg:mantle fg:bright-green)[$count](fg:white bg:mantle bold) ";
        stashed = "[](bg:mantle fg:yellow) [$count](fg:white bg:mantle bold) ";
        style = "bg:mantle";
        untracked = "[ ](bg:mantle fg:bright-black)[$count](fg:white bg:mantle bold) ";
      };

      hostname = {
        format = "at [](fg:surface0)[󰍹 ](fg:lavender bg:surface0 bold)[](bg:mantle fg:surface0)[$hostname]($style)[](fg:mantle)";
        ssh_only = true;
        style = "fg:#ffffff bold bg:mantle";
      };

      palette = "catppuccin_mocha";

      palettes = {
        catppuccin_mocha = {
          base = "#1e1e2e";
          blue = "#89b4fa";
          crust = "#11111b";
          flamingo = "#f2cdcd";
          green = "#a6e3a1";
          lavender = "#b4befe";
          mantle = "#181825";
          maroon = "#eba0ac";
          mauve = "#cba6f7";
          overlay0 = "#6c7086";
          overlay1 = "#7f849c";
          overlay2 = "#9399b2";
          peach = "#fab387";
          pink = "#f5c2e7";
          red = "#f38ba8";
          rosewater = "#f5e0dc";
          sapphire = "#74c7ec";
          sky = "#89dceb";
          subtext0 = "#a6adc8";
          subtext1 = "#bac2de";
          surface0 = "#313244";
          surface1 = "#45475a";
          surface2 = "#585b70";
          teal = "#94e2d5";
          text = "#cdd6f4";
          yellow = "#f9e2af";
        };
      };

      shell = {
        disabled = false;
        format = "[](fg:surface0)[ ](bg:surface0 fg:peach)[](fg:surface0 bg:mantle)[ $indicator]($style)[](fg:mantle)";
        style = "fg:#ffffff bg:mantle bold";
      };

      username = {
        disabled = false;
        format = "on [](fg:surface0)[ ](bg:surface0 fg:green bold)[](bg:mantle fg:surface0)[ $user]($style)[](fg:mantle)";
        show_always = true;
        style_root = "fg:red bold bg:mantle";
        style_user = "fg:#ffffff bold bg:mantle";
      };
    };
  };
}
