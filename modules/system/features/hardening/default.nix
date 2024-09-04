{lib, ...}: let
  inherit
    (builtins)
    attrNames
    readDir
    ;
  inherit
    (lib)
    fold
    filterAttrs
    mkEnableOption
    ;

  # Every subdirectory here represents a module
  modules =
    # Get only the attribute names (returns a list of strings)
    attrNames
    # Filter attribute set
    (filterAttrs
      # Find the ones that are directories themselves
      (_name: value: value == "directory")
      # List all files in the current directory
      (readDir ./.));

  mkModuleOption = name: {
    ${name}.enable = mkEnableOption "Whether or not to enable hardening for the ${name}.";
  };
in {
  options.laplace.features.hardening = fold (curr: acc: acc // (mkModuleOption curr)) {} modules;

  imports = map (name: "${./.}/${name}") modules;
}
