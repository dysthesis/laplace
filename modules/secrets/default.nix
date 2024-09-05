{
  inputs,
  lib,
  config,
  ...
}: let
  inherit (builtins) attrNames;
  inherit
    (lib)
    filterAttrs
    fold
    ;

  enabledUsers =
    attrNames
    (filterAttrs
      (_name: value: value.enable)
      config.laplace.users);
in {
  imports = [inputs.sops-nix.nixosModules.sops];
  sops.defaultSopsFile = ./secrets.yaml;

  # Require the hashed passwords for enabled users.
  sops.secrets =
    # User passwords
    (fold
      (curr: acc:
        acc
        // {
          "hashedPasswords/${curr}".neededForUsers = true;
        })
      {}
      enabledUsers)
    // {
      "luksPasswords/main" = {};
    };

  # TODO: Adjust this to account for impermanence
  sops.age.keyFile = "/etc/secrets/age/keys.txt";
}
