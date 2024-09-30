{
  config,
  lib,
  inputs,
  ...
}: let
  inherit
    (lib)
    fold
    filterAttrs
    ;
  inherit (builtins) attrNames;
in {
  imports = [inputs.sops-nix.nixosModules.sops];
  sops.defaultSopsFile = ./secrets.yaml;

  # Require the hashed passwords for enabled users.
  sops.secrets = let
    enabledUsers =
      attrNames
      (filterAttrs
        (_name: value: value.enable)
        config.laplace.users);
  in
    # User passwords
    fold
    (curr: acc:
      acc
      // {
        "hashedPasswords/${curr}".neededForUsers = true;
      })
    {}
    enabledUsers;

  sops.age.keyFile = "/nix/persist/etc/secrets/age/keys.txt";
}
