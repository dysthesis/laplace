{inputs, ...}: {
  imports = [inputs.sops-nix.nixosModules.sops];
  sops = {
    defaultSopsFile = ./secrets.yaml;
    age.keyFile = "/nix/persist/etc/secrets/age/keys.txt";
  };
}
