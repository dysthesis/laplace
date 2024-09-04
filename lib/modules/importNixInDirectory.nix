lib: let
  inherit
    (builtins)
    readDir
    attrNames
    ;
  inherit
    (lib)
    filter
    filterAttrs
    hasSuffix
    ;

  inCwd = cwd: filterAttrs isFile (readDir cwd);
  isNixFile = file: hasSuffix ".nix" file;
  isFile = _: value: value == "regular";
in
  currFile: cwd:
    map
    (file: "${cwd}/${file}")
    (filter
      (name: isNixFile name && name != currFile)
      (attrNames (inCwd cwd)))
