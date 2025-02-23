{
  inputs,
  pkgs,
  fish,
  fishPlugins,
  lib,
  starship,
  zoxide,
  writeTextDir,
  writeText,
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
  initPlugin = plugin: ''
    begin
      set -l __plugin_dir ${plugin}/share/fish
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
    foreign-env
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
      ":q" = "exit";
      "v" = "${getExe inputs.poincare.packages.${pkgs.system}.default}";
      sudo = "doas";
    }
    // ezaAliases;

  formatAliases = mapAttrsToList (name: value: "alias ${name}=${escapeShellArg value}");
  deps = with pkgs; lib.makeBinPath [zoxide];
  fish_user_config = writeText "user_config.fish" ''
    # Only source once
    # set -q __fish_config_sourced; and exit
    # set -gx __fish_config_sourced 1
    ${lib.concatMapStringsSep "\n" initPlugin plugins}

    if status is-login
      fenv source /etc/profile
    end

    if status is-interactive
      ${lib.fileContents ./interactive.fish}
      ${lib.fileContents ./pushd_mod.fish}
      function starship_transient_prompt_func
        ${lib.getExe starship} module character
      end
      ${lib.getExe starship} init fish | source
      ${lib.getExe zoxide} init fish | source
      enable_transience
      set -gx DIRENV_LOG_FORMAT ""
      set -gx direnv_config_dir ${direnvConfig}
      ${lib.getExe direnv} hook fish | source
    end

    set PATH ${deps} $PATH

    # Load aliases
    ${concatStringsSep "\n" (formatAliases aliases)}
  '';
in
  fish.overrideAttrs (old: {
    patches = [./fish-on-tmpfs.patch];
    doCheck = false;
    postInstall =
      old.postInstall
      + ''
        echo "source ${fish_user_config}" >> $out/etc/fish/config.fish
      '';
  })
