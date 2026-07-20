{
  pkgs,
  lib,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
  inherit (pkgs.writers) writeTOML;
  jjConfig = import ./config.nix {inherit pkgs lib;};
  config = writeTOML "jujutsu-config" jjConfig;
in
  (mkWrapper pkgs pkgs.unstable.jujutsu {set.JJ_CONFIG = config;})
  .overrideAttrs (old: {
    # Expose the config so other wrappers (jjui) can derive their commands
    # from the same alias definitions instead of duplicating them. passthru
    # is not hashed, so this does not change the derivation.
    passthru = (old.passthru or {}) // {inherit jjConfig;};
  })
