{
  pkgs,
  lib,
  notmuch,
  neomutt,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
  inherit (lib) makeBinPath;

  config = import ./config.nix {inherit pkgs lib;};
  pythonWithDeps = pkgs.python3.withPackages (ps: [
    ps.requests
  ]);

  deps = [
    notmuch
    pkgs.cacert # SSL certificate validation
    pythonWithDeps
  ];
in
  mkWrapper pkgs neomutt ''
    wrapProgram $out/bin/neomutt \
      --add-flags "-F ${config}" \
      --prefix PATH : "${makeBinPath deps}"
  ''
