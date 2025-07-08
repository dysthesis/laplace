{
  pkgs,
  lib,
  notmuch,
  neomutt,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
  inherit (lib) makeBinPath;

  # Create a python environment with the dependencies for your oauth script.
  # Add any other libraries your script needs to this list.
  pythonWithDeps = pkgs.python3.withPackages (ps: [
    ps.requests
    # ps.keyring # This is often another dependency, add if needed
    # ps.requests-oauthlib # Add if needed
  ]);

  deps = [
    notmuch
    pkgs.cacert # Essential for SSL certificate validation
    pythonWithDeps # This adds the python interpreter with its libs to the PATH
  ];
in
  mkWrapper pkgs neomutt ''
    wrapProgram $out/bin/neomutt \
      --add-flags "-F ${./neomuttrc}" \
      --prefix PATH : "${makeBinPath deps}"
  ''
