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
    # Expose aliases to jjui without changing the derivation hash.
    passthru = (old.passthru or {}) // {inherit jjConfig;};
  })
