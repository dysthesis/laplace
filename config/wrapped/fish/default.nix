{
  inputs,
  pkgs,
  fish,
  fishPlugins,
  lib,
  starship,
  writeTextDir,
  writeText,
  nix-direnv,
  direnv,
}:
let
  inherit (lib.strings)
    concatStringsSep
    escapeShellArg
    ;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib) getExe;
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
  aliases = {
    ":q" = "exit";
    "v" = "${getExe inputs.poincare.packages.${pkgs.system}.default}";
    sudo = "doas";
  };

  formatAliases = mapAttrsToList (name: value: "alias ${name}=${escapeShellArg value}");
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
        enable_transience
        set -gx DIRENV_LOG_FORMAT ""
        set -gx direnv_config_dir ${direnvConfig}
        ${lib.getExe direnv} hook fish | source
      end

      # Load aliases
    ${concatStringsSep "\n" (formatAliases aliases)}
  '';
in
fish.overrideAttrs (old: {
  patches = [ ./fish-on-tmpfs.patch ];
  doCheck = false;
  postInstall =
    old.postInstall
    + ''
      echo "source ${fish_user_config}" >> $out/etc/fish/config.fish
    '';
})
