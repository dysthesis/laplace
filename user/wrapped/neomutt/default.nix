{
  pkgs,
  lib,
  notmuch,
  neomutt,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;

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
  mkWrapper pkgs neomutt {
    addFlags = ["-F ${config}"];
    binPath = deps;
  }
