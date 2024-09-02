{lib, ...}: let
  inherit (lib.laplace) mkSystem;

  # Map each host to its architecture
  hosts = {
    "yaldabaoth" = "x86_64";
  };
in {
  flake.nixosConfigurations = map (hostname: system:
    mkSystem {
      inherit system hostname;
      config = [
        ./${hostname}
        ../modules
      ];
    })
  hosts;
}
