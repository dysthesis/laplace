lib: let
  inherit (lib.laplace.modules) fromDirectories;
in
  dir:
    map
    (module: "${dir}/${module}")
    (fromDirectories dir)
