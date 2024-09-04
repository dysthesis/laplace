{
  self,
  inputs,
  lib,
  config,
  ...
}: let
  inherit
    (builtins)
    mapAttrs
    attrNames
    pathExists
    ;
  inherit
    (lib)
    fold
    filterAttrs
    mkEnableOption
    assertMsg
    ;
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
  # to enable the user in the given system, as well as whether or not home-manager should be used
  options.laplace.users =
    mapAttrs
    (name: value:
      value
      // {
        useHomeManager =
          mkEnableOption "Whether or not to enable home-manager for the user ${name}";
      })
    (enableOptsFromDir ./. "Whether or not to enable the user");

  config.home-manager = {
    useUserPackages = true;
    useGlobalPkgs = true;
    extraSpecialArgs = {
      inherit inputs;
      systemConfig = config;
    };
    users = let
      usersWithHM =
        attrNames
        (filterAttrs
          (_name: value: value.useHomeManager)
          config.laplace.users);
    in
      fold
      (curr: acc: let
        configPath = "${self}/modules/home/${curr}";
      in
        assert assertMsg
        (pathExists configPath)
        "The configurations for user ${curr} does not exist";
          acc
          // {
            "${curr}" = import configPath;
          })
      {}
      usersWithHM;
  };

  # Import all the user configurations
  imports =
    (importInDirectory ./.)
    ++ [inputs.home-manager.nixosModules.home-manager];
}
