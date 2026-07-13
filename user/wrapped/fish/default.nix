{
  inputs,
  pkgs,
  fish,
  fishPlugins,
  lib,
  starship,
  zoxide,
  atuin,
  writeTextDir,
  nix-direnv,
  direnv,
}: let
  inherit (lib) nameValuePair;
  inherit
    (lib.strings)
    concatStringsSep
    escapeShellArg
    ;
  inherit
    (lib.attrsets)
    attrNames
    mapAttrsToList
    mapAttrs'
    ;
  inherit (lib.laplace.pkgs) mkWrapper;
  inherit (pkgs.stdenv.hostPlatform) system;
  vendorConf = "share/fish/vendor_conf.d";

  plugins = with fishPlugins; [
    fzf-fish
    autopair
  ];

  # `tool init | source` forks the tool on every shell start only to produce
  # text that is a pure function of the tool's store path. Capture that text
  # once at build time and `source` it as a plain file instead: identical
  # bytes reach the parser, but a read replaces a fork+exec (and, for
  # starship, the mktemp/cat/rm trio its psub-based shim would spawn).
  starshipInit = pkgs.runCommand "starship-init.fish" {} ''
    HOME="$TMPDIR" ${lib.getExe starship} init fish --print-full-init > $out
  '';
  # The generated script ends in `alias cd=__zoxide_z`, which costs an
  # `echo … | source` round-trip at startup; expand it to the exact function
  # definition fish's `alias` would build.
  zoxideInit = pkgs.runCommand "zoxide-init.fish" {} ''
    HOME="$TMPDIR" ${lib.getExe zoxide} init fish --cmd cd \
      | sed "s|^alias cd=__zoxide_z\$|function cd --wraps=__zoxide_z --description 'alias cd=__zoxide_z'\n    __zoxide_z \$argv\nend|" \
      > $out
  '';
  direnvHook = pkgs.runCommand "direnv-hook.fish" {} ''
    HOME="$TMPDIR" ${lib.getExe direnv} hook fish > $out
  '';

  # Plugin function/completion paths, resolved at build time instead of
  # stat'ing every directory on every shell start. vendor_conf.d is
  # deliberately not sourced, matching the behaviour of the load_plugin
  # function this replaces.
  pluginPaths = pkgs.runCommand "fish-plugin-paths.fish" {} ''
    touch $out
    for p in ${concatStringsSep " " (map toString plugins)}; do
      d="$p/share/fish"
      if [ -d "$d/vendor_functions.d" ]; then
        echo "set -p fish_function_path $d/vendor_functions.d" >> $out
      fi
      if [ -d "$d/vendor_completions.d" ]; then
        echo "set -p fish_complete_path $d/vendor_completions.d" >> $out
      fi
    done
  '';

  # Functions that used to be parsed inline at every startup, now autoloaded
  # on first use via fish's vendor_functions.d mechanism.
  functionsDir = pkgs.runCommand "fish-vendor-functions" {} ''
    install -Dm444 ${./functions/pushd.fish} $out/share/fish/vendor_functions.d/pushd.fish
    install -Dm444 ${./functions/popd.fish} $out/share/fish/vendor_functions.d/popd.fish
  '';

  direnvConfig = writeTextDir "direnvrc" ''
    source ${nix-direnv}/share/nix-direnv/direnvrc
  '';

  aliases = with pkgs; let
    inherit (lib) getExe;
    baseAliases = {
      ls = "${getExe eza} --icons";
      ll = "${getExe eza} --icons -l";
      la = "${getExe eza} --icons -la";
    };
    treeAliases = mapAttrs' (name: value: nameValuePair (name + "t") (value + " --tree")) baseAliases;
    ezaAliases = baseAliases // treeAliases;
  in
    {
      "t" = "${getExe pkgs.configured.taskwarrior}";
      ":q" = "exit";
      "v" = "${getExe inputs.poincare.packages.${system}.default}";
      sudo = "doas";
      bat = "bat --theme=base16 --style=changes,header --plain";
      cat = "${getExe bat}";
      notes = "${
        getExe inputs.daedalus.packages.${system}.default
      } new-session -As Notes -c ~/Documents/Notes/Contents ${getExe direnv} exec . $EDITOR";
      temp = "cd $(mktemp -d)";
      subs = "${pkgs.configured.ytfzf}/bin/ytfzf -cS --sort";
    }
    // ezaAliases;

  # fish's `alias` builtin assembles each function and feeds it through
  # `echo … | source` at every startup. Run `alias` once at build time (so its
  # exact wrapping/description/`command` semantics are preserved) and source
  # the resulting function definitions directly.
  aliasesFile = let
    gen = pkgs.writeText "gen-aliases.fish" ''
      ${concatStringsSep "\n" (mapAttrsToList (name: value: "alias ${escapeShellArg name} ${escapeShellArg value}") aliases)}
      functions ${concatStringsSep " " (map escapeShellArg (attrNames aliases))}
    '';
  in
    pkgs.runCommand "fish-aliases.fish" {} ''
      HOME="$TMPDIR" XDG_RUNTIME_DIR="$TMPDIR" ${lib.getExe fish} --no-config ${gen} > $out
    '';

  # The Radicale collection that TaskDroid mirrors Taskwarrior into; excluded
  # from the startup agenda since those events duplicate the `task next` list
  # above. Stable as long as the Radicale collection isn't recreated.
  taskMirrorCalendar = "08dc09ab-c6bf-1a74-8019-003a57d72f37";

  deps = with pkgs;
    lib.makeBinPath [
      zoxide
      atuin
      fzf
      fd
      ripgrep
      bat
    ];

  config =
    writeTextDir "${vendorConf}/user_config.fish"
    # fish
    ''
      source ${pluginPaths}

      set -gx EZA_COLORS 'ex=38;2;120;153;120:fi=38;2;204;204;204:di=38;2;85;85;85:b0=38;2;215;0;0:or=38;2;215;0;0:ln=38;2;112;128;144:lp=38;2;112;128;144:lc=38;2;112;128;144:lm=38;2;112;128;144:bd=38;2;119;136;170:cd=38;2;119;136;170:pi=38;2;119;136;170:so=38;2;119;136;170:ur=38;2;122;122;122:uw=38;2;122;122;122:ux=38;2;122;122;122:ue=38;2;122;122;122:gr=38;2;122;122;122:gw=38;2;122;122;122:gx=38;2;122;122;122:tr=38;2;122;122;122:tw=38;2;122;122;122:tx=38;2;122;122;122:su=38;2;122;122;122:sf=38;2;122;122;122:xa=38;2;122;122;122:hd=38;2;68;68;68:bl=38;2;122;122;122:cc=38;2;122;122;122:da=38;2;122;122;122:in=38;2;122;122;122:xx=38;2;122;122;122:ga=38;2;120;153;120:gd=38;2;255;170;136:gm=38;2;119;136;170:gv=38;2;119;136;170:gt=38;2;119;136;170:df=38;2;122;122;122:ds=38;2;122;122;122:sb=38;2;85;85;85:sn=38;2;170;170;170:uu=38;2;85;85;85:un=38;2;85;85;85:gu=38;2;85;85;85:gn=38;2;85;85;85:sc=38;2;204;204;204:bu=38;2;204;204;204:cm=38;2;122;122;122:tm=38;2;122;122;122:co=38;2;122;122;122:do=38;2;122;122;122:cr=38;2;255;170;136:im=38;2;122;122;122:lo=38;2;122;122;122:mu=38;2;122;122;122:vi=38;2;122;122;122:mp=38;2;122;122;122'

      if status is-login
        fenv source /etc/profile
      end

      if status is-interactive
        ${lib.fileContents ./interactive.fish}
        set -gx STARSHIP_CONFIG ${./starship.toml}
        function starship_transient_prompt_func
          ${lib.getExe starship} module character
        end
        set -gx DIRENV_LOG_FORMAT ""
        set -gx direnv_config_dir ${direnvConfig}
        source ${direnvHook}
        dbus-update-activation-environment --systemd --all
        ${lib.getExe pkgs.configured.taskwarrior} next due.before:today+7d
        ${lib.getExe pkgs.configured.khal} list -d ${taskMirrorCalendar} now today
      end

      function cpfile
          for file in $argv
              echo "file://" (realpath $file)
          end | wl-copy --type text/uri-list
      end

      function git
          if test (count $argv) -eq 0
              ${lib.getExe pkgs.lazygit}
          else
              command git $argv
          end
      end

      set PATH ${deps} $PATH

      source ${aliasesFile}

      source ${starshipInit}
      source ${zoxideInit}

      enable_transience
    '';
in
  mkWrapper pkgs fish
  # bash
  ''
    wrapProgram $out/bin/fish \
      --prefix XDG_DATA_DIRS : "${
      lib.makeSearchPathOutput "out" "share" [
        functionsDir
        config
      ]
    }"
  ''
