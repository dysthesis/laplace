{
  self,
  lib,
  ...
}: let
  inherit (lib.laplace) mkSystem;
  inherit (builtins) mapAttrs;

  # Map each host to its architecture
  hosts = {
    "yaldabaoth" = "x86_64-linux";
    "astaphaios" = "x86_64-linux";
    "adonaios" = "x86_64-linux";
  };
in {
  flake.nixosConfigurations = mapAttrs (hostname: system:
    mkSystem {
      inherit system hostname self;
      specialArgs = {inherit lib;};
      config = [
        ./${hostname}
        "${self}/modules/system"
        "${self}/modules/secrets"
      ];
    })
  hosts;
}
