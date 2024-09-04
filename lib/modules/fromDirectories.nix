lib: let
  inherit
    (lib)
    filterAttrs
    ;

  inherit
    (builtins)
    readDir
    attrNames
    ;

  getDirectories = contents:
  # Filter attribute set
    filterAttrs
    # Find the ones that are directories themselves
    (_name: value: value == "directory")
    contents;
in
  # Get only the attribute names (returns a list of strings)
  dir:
    attrNames
    (getDirectories (readDir dir))
