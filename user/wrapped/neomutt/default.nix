{
  pkgs,
  lib,
  notmuch,
  neomutt,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
  inherit (lib) makeBinPath;

  config = import ./config.nix {inherit pkgs lib;};
  pythonWithDeps = pkgs.python3.withPackages (ps: [
    ps.requests
  ]);

  deps = [
    notmuch
    pkgs.cacert # Essential for SSL certificate validation
    pythonWithDeps # This adds the python interpreter with its libs to the PATH
  ];
in
  mkWrapper pkgs neomutt ''
    wrapProgram $out/bin/neomutt \
      --add-flags "-F ${config}" \
      --prefix PATH : "${makeBinPath deps}"
  ''
