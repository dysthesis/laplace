{
  lib,
  pkgs,
  lazygit,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
  cfg = pkgs.writers.writeYAML (import ./config.nix {});
in
  mkWrapper pkgs lazygit
  # sh
  ''
    wrapProgram $out/bin/lazygit \
      --add-flags "--use-config-file=\"${cfg}\""
  ''
