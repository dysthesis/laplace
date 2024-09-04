{inputs, ...}: {
  imports = [inputs.sops-nix.nixosModules.sops];
  sops.defaultSopsFile = ./secrets.yaml;
  sops.secrets."hashedPasswords/demiurge" = {
    neededForUsers = true;
  };

  # TODO: Adjust this to account for impermanence
  sops.age.keyFile = "/home/demiurge/.config/sops/age/keys.txt";
}
