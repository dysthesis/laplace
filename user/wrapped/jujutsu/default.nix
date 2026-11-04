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
    # Give jjui access to aliases without a new derivation hash.
    passthru = (old.passthru or {}) // {inherit jjConfig;};
  })
