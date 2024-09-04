{
  lib,
  config,
  ...
}: let
  inherit
    (lib.laplace.modules)
    enableOptsFromDir
    importInDirectory
    ;
in {
  # Impermanence means state will not be preserved. Letting users be mutable means that any changes
  # would not be saved. It would be better to enforce that changes to a user must be done
  # declaratively, through this configuration, rather than imperatively.
  config.users.mutableUsers = !config.laplace.features.impermanence.enable;

  # For each user (represented by a subdirectory in modules/system/core/users), create an option
  # to enable the user in the given system.
  options.laplace.users = enableOptsFromDir ./. "Whether or not to enable the user";

  # Import all the user configurations
  imports = importInDirectory ./.;
}
