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
    mapAttrsToList
    mapAttrs'
    ;
  inherit (lib.babel.pkgs) mkWrapper;
  vendorConf = "share/fish/vendor_conf.d";
  loadPlugin =
    pkgs.writeTextDir "${vendorConf}/load_plugin.fish"
    # fish
    ''
      function load_plugin
        if test (count $argv) -lt 1
          echo Failed to load plugin, incorrect number of arguments
          return 1
        end
        set -l __plugin_dir $argv[1]/share/fish
        if test -d $__plugin_dir/vendor_functions.d
          set -p fish_function_path $__plugin_dir/vendor_functions.d
        end
        if test -d $__plugin_dir/vendor_completions.d
          set -p fish_complete_path $__plugin_dir/vendor_completions.d
        end
        if test -d $__plugin_dir/vendor_conf.d
          for f in $plugin_dir/vendor_conf.d/*.fish
            source $f
          end
        end
      end
    '';
  plugins = with fishPlugins; [
    fzf-fish
    autopair
  ];
  direnvConfig = writeTextDir "direnvrc" ''
    source ${nix-direnv}/share/nix-direnv/direnvrc
  '';

  # NOTE: Add aliases here
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
      "v" = "${getExe inputs.poincare.packages.${pkgs.system}.default}";
      sudo = "doas";
      cat = "${getExe bat}";
      notes = "${getExe inputs.daedalus.packages.${system}.default} new-session -As Notes -c ~/Documents/Notes/Contents ${getExe direnv} exec . $EDITOR";
      temp = "cd $(mktemp -d)";
      subs = "${pkgs.configured.ytfzf}/bin/ytfzf -cS --sort";
      rd = "${getExe pkgs.configured.read}";
    }
    // ezaAliases;

  formatAliases = mapAttrsToList (name: value: "alias ${name}=${escapeShellArg value}");
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
      # Only source once
      # set -q __fish_config_sourced; and exit
      # set -gx __fish_config_sourced 1
      ${plugins |> (map (elem: "load_plugin ${elem}")) |> (lib.concatStringsSep "\n")}

      # Eza colours
      set -gx EZA_COLORS 'ex=38;2;120;153;120:fi=38;2;204;204;204:di=38;2;85;85;85:b0=38;2;215;0;0:or=38;2;215;0;0:ln=38;2;112;128;144:lp=38;2;112;128;144:lc=38;2;112;128;144:lm=38;2;112;128;144:bd=38;2;119;136;170:cd=38;2;119;136;170:pi=38;2;119;136;170:so=38;2;119;136;170:ur=38;2;122;122;122:uw=38;2;122;122;122:ux=38;2;122;122;122:ue=38;2;122;122;122:gr=38;2;122;122;122:gw=38;2;122;122;122:gx=38;2;122;122;122:tr=38;2;122;122;122:tw=38;2;122;122;122:tx=38;2;122;122;122:su=38;2;122;122;122:sf=38;2;122;122;122:xa=38;2;122;122;122:hd=38;2;68;68;68:bl=38;2;122;122;122:cc=38;2;122;122;122:da=38;2;122;122;122:in=38;2;122;122;122:xx=38;2;122;122;122:ga=38;2;120;153;120:gd=38;2;255;170;136:gm=38;2;119;136;170:gv=38;2;119;136;170:gt=38;2;119;136;170:df=38;2;122;122;122:ds=38;2;122;122;122:sb=38;2;85;85;85:sn=38;2;170;170;170:uu=38;2;85;85;85:un=38;2;85;85;85:gu=38;2;85;85;85:gn=38;2;85;85;85:sc=38;2;204;204;204:bu=38;2;204;204;204:cm=38;2;122;122;122:tm=38;2;122;122;122:co=38;2;122;122;122:do=38;2;122;122;122:cr=38;2;255;170;136:im=38;2;122;122;122:lo=38;2;122;122;122:mu=38;2;122;122;122:vi=38;2;122;122;122:mp=38;2;122;122;122'

      if status is-login
        fenv source /etc/profile
      end

      if status is-interactive
        ${lib.fileContents ./interactive.fish}
        ${lib.fileContents ./pushd_mod.fish}
        set -gx STARSHIP_CONFIG ${./starship.toml}
        function starship_transient_prompt_func
          ${lib.getExe starship} module character
        end
        set -gx DIRENV_LOG_FORMAT ""
        set -gx direnv_config_dir ${direnvConfig}
        ${lib.getExe direnv} hook fish | source
        dbus-update-activation-environment --systemd --all
        task list
      end

      function cpfile
          for file in $argv
              # Convert the file path to an absolute path and prepend the file URI scheme
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

      # Load aliases
      ${concatStringsSep "\n" (formatAliases aliases)}

      ${lib.getExe starship} init fish | source
      ${lib.getExe zoxide} init fish --cmd cd | source

      enable_transience
    '';
in
  mkWrapper pkgs fish
  # bash
  ''
    wrapProgram $out/bin/fish \
      --prefix XDG_DATA_DIRS : "${
      lib.makeSearchPathOutput "out" "share" [
        loadPlugin
        config
      ]
    }"
  ''
