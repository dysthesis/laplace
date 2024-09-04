lib: let
  inherit
    (lib.laplace.modules)
    fromDirectories
    toEnableOptions
    ;

  inherit (lib) fold;
in
  dir: desc:
    fold
    (curr: acc: acc // (toEnableOptions desc curr))
    {}
    (fromDirectories dir)
