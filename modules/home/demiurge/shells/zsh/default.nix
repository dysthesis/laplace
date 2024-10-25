{
  systemConfig,
  config,
  pkgs,
  lib,
  ...
}: let
  inherit
    (lib)
    getExe
    ;
in {
  programs.zsh = {
    enable = true;
    dotDir = ".config/zsh";

    sessionVariables = {LC_ALL = "en_AU.UTF-8";};

    enableCompletion = true;
    autosuggestion.enable = true;

    syntaxHighlighting = {
      enable = true;
      highlighters = ["brackets"];
    };

    shellAliases = with pkgs;
      {
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
      }
      // (
        if systemConfig.laplace.features.podman.enable
        then {
          docker = "podman";
        }
        else {}
      );

    history = {
      # share history between different zsh sessions
      share = true;
      # avoid cluttering $HOME with the histfile
      path = "${config.xdg.dataHome}/zsh/zsh_history";
      # saves timestamps to the histfile
      extended = true;
      # optimize size of the histfile by avoiding duplicates
      # or commands we don't need remembered
      save = 10000;
      size = 10000;
      expireDuplicatesFirst = true;
      ignoreDups = true;
      ignoreSpace = true;
      ignorePatterns = ["rm *" "pkill *" "kill *"];
    };

    loginExtra =
      /*
      zsh
      */
      ''
        if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
          Hyprland
        fi
      '';

    completionInit =
      /*
      zsh
      */
      ''
           autoload -Uz compinit
           zstyle ':completion:*' menu select
           zmodload zsh/complist
           compinit -d "$XDG_CACHE_HOME"/zsh/zcompdump-"$ZSH_VERSION"
           _comp_options+=(globdots)

           # Group matches and describe.
           zstyle ':completion:*' sort false
           zstyle ':completion:complete:*:options' sort false
           zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' 'm:{[:lower:][:upper:]}={[:upper:][:lower:]} l:|=* r:|=*' 'm:{[:lower:][:upper:]}={[:upper:][:lower:]} l:|=* r:|=*' 'm:{[:lower:][:upper:]}={[:upper:][:lower:]} l:|=* r:|=*'
           zstyle ':completion:*' special-dirs true
           zstyle ':completion:*' rehash true

           # open commands in $EDITOR
           autoload -z edit-command-line
           zle -N edit-command-line
           bindkey "^e" edit-command-line

           zstyle ':completion:*' menu yes select # search
           zstyle ':completion:*' list-grouped false
           zstyle ':completion:*' list-separator '''
           zstyle ':completion:*' group-name '''
           zstyle ':completion:*' verbose yes
           zstyle ':completion:*:matches' group 'yes'
           zstyle ':completion:*:warnings' format '%F{red}%B-- No match for: %d --%b%f'
           zstyle ':completion:*:messages' format '%d'
           zstyle ':completion:*:corrections' format '%B%d (errors: %e)%b'
           zstyle ':completion:*:descriptions' format '[%d]'

           # Fuzzy match mistyped completions.
           zstyle ':completion:*' completer _complete _match _approximate
           zstyle ':completion:*:match:*' original only
           zstyle ':completion:*:approximate:*' max-errors 1 numeric

           # Don't complete unavailable commands.
           zstyle ':completion:*:functions' ignored-patterns '(_*|pre(cmd|exec))'

           # Array completion element sorting.
           zstyle ':completion:*:*:-subscript-:*' tag-order indexes parameters

           # Colors
           zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}

           # Jobs id
           zstyle ':completion:*:jobs' numbers true
           zstyle ':completion:*:jobs' verbose true

           # Sort completions
           zstyle ":completion:*:git-checkout:*" sort false
           zstyle ':completion:*' file-sort modification
           zstyle ':completion:*:${lib.getExe pkgs.eza} --icons' sort false
           zstyle ':completion:files' sort false
        zstyle ':completion:*' insert-sections true

           # fzf-tab
           zstyle ':fzf-tab:complete:_zlua:*' query-string input
           zstyle ':fzf-tab:complete:kill:argument-rest' fzf-preview 'ps --pid=$word -o cmd --no-headers -w -w'
           zstyle ':fzf-tab:complete:kill:argument-rest' fzf-flags '--preview-window=down:3:wrap'
           zstyle ':fzf-tab:complete:kill:*' popup-pad 0 3
           zstyle ':fzf-tab:complete:cd:*' fzf-preview '${lib.getExe pkgs.eza} -1 --icons --color=always $realpath'
           zstyle ':fzf-tab:complete:cd:*' popup-pad 30 0
           zstyle ':fzf-tab:*' switch-group ',' '.'
      '';

    initExtraFirst =
      /*
      zsh
      */
      ''
        # set my zsh options, first things
        source ${./opts.zsh}
        set -k
        export FZF_DEFAULT_OPTS=" \
        --color=bg+:#1e1e2e,bg:-1,spinner:#f5e0dc,hl:#f38ba8 \
        --color=fg:#ffffff,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
        --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
        --prompt ' '"

        zmodload zsh/zle
        zmodload zsh/zpty
        zmodload zsh/complist

        # Colors
        autoload -Uz colors && colors

        # Autosuggest
        ZSH_AUTOSUGGEST_USE_ASYNC="true"

        # Vi mode
        bindkey -v

        # Use vim keys in tab complete menu:
        bindkey -M menuselect 'h' vi-backward-char
        bindkey -M menuselect 'k' vi-up-line-or-history
        bindkey -M menuselect 'l' vi-forward-char
        bindkey -M menuselect 'j' vi-down-line-or-history

        bindkey "^A" vi-beginning-of-line
        bindkey "^E" vi-end-of-line

        # If this is an xterm set the title to user@host:dir
        case "$TERM" in
        xterm*|rxvt*|Eterm|aterm|kterm|gnome*|alacritty|kitty*)
          TERM_TITLE=$'\e]0;%n@%m: %1~\a'
            ;;
        *)
            ;;
        esac
      '';

    plugins = with pkgs; [
      {
        # Must be before plugins that wrap widgets
        # such as zsh-autosuggestions or fast-syntax-highlighting
        name = "fzf-tab";
        file = "fzf-tab.plugin.zsh";
        src = "${zsh-fzf-tab}/share/fzf-tab";
      }
      {
        name = "nix-shell";
        file = "nix-shell.plugin.zsh";
        src = "${zsh-nix-shell}/share/zsh-nix-shell";
      }
      {
        name = "zsh-vi-mode";
        file = "zsh-vi-mode.plugin.zsh";
        src = "${zsh-vi-mode}/share/zsh-vi-mode";
      }
      {
        name = "fast-syntax-highlighting";
        file = "fast-syntax-highlighting.plugin.zsh";
        src = "${zsh-fast-syntax-highlighting}/share/zsh/site-functions";
      }
      {
        name = "zsh-autosuggestions";
        file = "zsh-autosuggestions.zsh";
        src = "${zsh-autosuggestions}/share/zsh-autosuggestions";
      }
      {
        name = "zsh-autopair";
        file = "autopair.zsh";
        src = "${zsh-autopair}/share/zsh/zsh-autopair";
      }
    ];
  };
}
