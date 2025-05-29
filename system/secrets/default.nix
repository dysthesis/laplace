{inputs, ...}: {
  imports = [inputs.sops-nix.nixosModules.sops];
  sops = {
    secrets.libera = {owner = "demiurge";};
    defaultSopsFile = ./secrets.yaml;
    age.keyFile = "/nix/persist/etc/secrets/age/keys.txt";
  };
}
