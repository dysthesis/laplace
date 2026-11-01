{
  pkgs,
  lib,
  direnv,
  nix,
  nix-direnv,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
  direnvConfig = {
    global = {
      log_format = "-";
      log_filter = "^$";
      hide_env_diff = true;
    };
  };
  direnvConfigFile = pkgs.writers.writeTOML "direnv.toml" direnvConfig;
  direnvConfigDir = pkgs.runCommandLocal "direnv-config" {} ''
    mkdir -p $out
    cp ${direnvConfigFile} $out/direnv.toml
    ln -s ${nix-direnv}/share/nix-direnv/direnvrc $out/direnvrc
  '';
in
  mkWrapper pkgs.unstable direnv {
    set.DIRENV_CONFIG = direnvConfigDir;
    binPath = [nix];

    # Hook commands use os.Executable(), which returns the unwrapped executable.
    run = [
      ''
        if [[ "''${1-}" == hook ]]; then
          unwrapped=${lib.escapeShellArg (lib.getExe direnv)}
          hook="$("$unwrapped" "$@")" || exit $?
          printf '%s\n' "''${hook//"$unwrapped"/@wrappedDirenv@}"
          exit 0
        fi
      ''
    ];
    postBuild = ''
      substituteInPlace $out/bin/direnv \
        --replace-fail '@wrappedDirenv@' "$out/bin/direnv"
    '';
  }
