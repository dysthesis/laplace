{
  lib,
  config,
  ...
}: let
  inherit
    (builtins)
    readDir
    attrNames
    ;

  inherit
    (lib)
    filterAttrs
    fold
    mkEnableOption
    ;

  # Every subdirectory here represents a user
  users =
    # Get only the attribute names (returns a list of strings)
    attrNames
    # Filter attribute set
    (filterAttrs
      # Find the ones that are directories themselves
      (_name: value: value == "directory")
      # List all files in the current directory
      (readDir ./.));

  mkUserOption = name: {
    ${name}.enable = mkEnableOption "Whether or not to enable the user ${name}.";
  };
in {
  # Impermanence means state will not be preserved. Letting users be mutable means that any changes
  # would not be saved. It would be better to enforce that changes to a user must be done
  # declaratively, through this configuration, rather than imperatively.
  config.users.mutableUsers = !config.laplace.features.impermanence.enable;

  # For each user (represented by a subdirectory in modules/system/core/users), create an option
  # to enable the user in the given system.
  options.laplace.users = fold (curr: acc: acc // (mkUserOption curr)) {} users;

  # Import all the user configurations
  imports = map (name: "${./.}/${name}") users;
}
