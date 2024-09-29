{inputs, ...}: {
  imports = [inputs.sops-nix.nixosModules.sops];
  sops.defaultSopsFile = ./secrets.yaml;

  # Require the hashed passwords for enabled users.
  # sops.secrets =
  #   # User passwords
  #   fold
  #   (curr: acc:
  #     acc
  #     // {
  #       "hashedPasswords/${curr}".neededForUsers = true;
  #     })
  #   {}
  #   enabledUsers;
  # // {
  #   "luksPasswords/${config.networking.hostName}" = {};
  # };

  sops.age.keyFile = "/nix/persist/etc/secrets/age/keys.txt";
}
