{pkgs}:
pkgs.runCommand "artifact-cleanup-check" {nativeBuildInputs = [pkgs.just];} ''
  mkdir -p nix/overlays sources result-directory
  touch nix/overlays/nix-output-monitor.nix sources/core sources/test result-file
  ln -s sources result
  ln -s missing result-broken
  ln -s sources not-a-result
  cp ${../../Justfile} Justfile
  substituteInPlace Justfile --replace-fail '#!/usr/bin/env sh' '#!${pkgs.runtimeShell}'
  just --justfile Justfile --working-directory "$PWD" clean
  test ! -L result
  test ! -L result-broken
  test -L not-a-result
  test -d result-directory
  test -f result-file
  test -f nix/overlays/nix-output-monitor.nix
  test -f sources/core
  test -f sources/test
  touch "$out"
''
