{
  self,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) getExe;
  sesh = getExe pkgs.sesh;
  tmux = getExe pkgs.tmux;
  fd = getExe pkgs.fd;
in {
  programs.tmux = {
    enable = true;
    clock24 = true;
    baseIndex = 1;
    prefix = "C-z";
    sensibleOnTop = true;
    terminal = "screen-256color";
    plugins = with pkgs.tmuxPlugins;
    with self.packages.${pkgs.system}; [
      oledppuccin-tmux
      yank
      {
        plugin = resurrect;
        extraConfig = "set -g @resurrect-strategy-nvim 'session'";
      }
      {
        plugin = continuum;
        extraConfig = ''
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
        set-option -sa terminal-overrides ",screen*:Tc"
        set-option -sa terminal-overrides ",screen-256color:RGB"
        set -g status-justify centre

        # Margin between statusbar
        set -Fg 'status-format[1]' '#{status-format[0]}'
        set -g 'status-format[0]' \'\'
        set -g status 2

        bind-key "T" run-shell "${sesh} connect \"$(
           ${sesh} list | fzf-tmux -p 55%,60% \
            --no-sort --ansi --border-label ' sesh ' --prompt '⚡  ' \
            --header '  ^a all ^t tmux ^g configs ^x zoxide ^d tmux kill ^f find' \
            --bind 'tab:down,btab:up' \
            --bind 'ctrl-a:change-prompt(⚡  )+reload(${sesh} list)' \
            --bind 'ctrl-t:change-prompt(🪟  )+reload(${sesh} list -t)' \
            --bind 'ctrl-g:change-prompt(⚙️  )+reload(${sesh} list -c)' \
            --bind 'ctrl-x:change-prompt(📁  )+reload(${sesh} list -z)' \
            --bind 'ctrl-f:change-prompt(🔎  )+reload(${fd} -H -d 2 -t d -E .Trash . ~)' \
            --bind 'ctrl-d:execute(${tmux} kill-session -t {})+change-prompt(⚡  )+reload(${sesh} list)'
        )\""
      '';
  };
  programs.fzf.tmux.enableShellIntegration = true;
}
