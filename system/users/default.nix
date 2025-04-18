{
  lib,
  config,
  ...
}:
let
  inherit (lib)
    mkOption
    ;
  inherit (lib.types)
    listOf
    enum
    ;
  inherit (lib.babel.modules) importInDirectory;
  inherit (lib.babel.path) getDirectories;
in
{
  config.users = {
    # Impermanence means state will not be preserved. Letting users be mutable means that any changes
    # would not be saved. It would be better to enforce that changes to a user must be done
    # declaratively, through this configuration, rather than imperatively.
    mutableUsers = !config.mnemosyne.enable;
    users.root.hashedPassword = "!";
  };

  # For each user (represented by a subdirectory in modules/system/core/users), create an option
  # to enable the user in the given system, as well as whether or not home-manager should be used
  options.laplace.users = mkOption {
    type = listOf (enum (getDirectories ./.));
    description = "Which users to enable";
    default = [ ];
  };

  # Import all the user configurations
  imports = importInDirectory ./.;
}
