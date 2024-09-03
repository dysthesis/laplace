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
  users = attrNames (filterAttrs
    (_name: value: value == "directory")
    (readDir ./.));

  mkUserOption = name: {${name}.enable = mkEnableOption "Whether or not to enable the user ${name}.";};
in {
  config.users.mutableUsers = !config.laplace.features.impermanence.enable;
  options.laplace.users = fold (curr: acc: acc // (mkUserOption curr)) {} users;
  imports = map (name: "${./.}/${name}") users;
}
