{
  self,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) getExe;
  sessioniser =
    pkgs.writeShellScriptBin "sessioniser"
    /*
    sh
    */
    ''
      if [ "$#" -eq 1 ]; then
      	selected=$1
      else
      	selected=$(fd --type directory --min-depth 0 --max-depth 1 --exclude Archives . ~/Documents/University/ ~/Documents/Projects/ | fzf --color=bg+:#1e1e2e,bg:-1,spinner:#f5e0dc,hl:#f38ba8 --color=fg:#ffffff,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8)
      fi

      if [ -z "$selected" ]; then
      	exit 0
      fi

      selected_name=$(basename "$selected" | tr . _)
      tmux_running=$(pgrep tmux)

      if [ -z "$TMUX" ] && [ -z "$tmux_running" ]; then
      	tmux new-session -s "$selected_name" -c "$selected"
      	exit 0
      fi

      if ! tmux has-session -t="$selected_name" 2>/dev/null; then
      	tmux new-session -ds "$selected_name" -c "$selected"
      fi

      tmux switch-client -t "$selected_name"
    '';
in {
  programs.tmux = {
    enable = true;

    aggressiveResize = true;
    secureSocket = true;
    keyMode = "vi";
    disableConfirmationPrompt = true;
    clock24 = true;
    mouse = true;
    baseIndex = 1;
    prefix = "C-z";
    sensibleOnTop = true;
    terminal = "screen-256color";
    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = tokyo-night;
        extraConfig =
          /*
          tmux
          */
          ''
            set -g @tokyo-night-tmux_show_datetime 0
            set -g @tokyo-night-tmux_show_path 1
            set -g @tokyo-night-tmux_path_format relative
            set -g @tokyo-night-tmux_window_id_style dsquare
            set -g @tokyo-night-tmux_window_id_style dsquare
            set -g @tokyo-night-tmux_show_git 0
            set -g @tokyo-night-tmux_path_format relative
            set -g @tokyo-night-tmux_show_git 1
          '';
      }
      yank
      sensible
      vim-tmux-navigator
      {
        plugin = resurrect;
        extraConfig =
          /*
          tmux
          */
          "set -g @resurrect-strategy-nvim 'session'";
      }
      {
        plugin = continuum;
        extraConfig =
          /*
          tmux
          */
          ''
            set -g @continuum-restore 'on'
            set -g @continuum-save-interval '60' # minutes
          '';
      }
    ];
    extraConfig =
      /*
      tmux
      */
      ''
        set -as terminal-features ",xterm-256color:RGB"
        bind -n C-f run-shell "tmux neww ${getExe sessioniser}"

        bind h select-pane -L
        bind j select-pane -D
        bind k select-pane -U
        bind l select-pane -R

        bind -n M-h select-pane -L
        bind -n M-j select-pane -D
        bind -n M-k select-pane -U
        bind -n M-l select-pane -R

        set -g allow-passthrough on
        set -g status-justify centre
        set -g @tmux_window_name_max_len "15"
        set-option -g renumber-windows on
      '';
  };
  programs.fzf.tmux.enableShellIntegration = true;
}
