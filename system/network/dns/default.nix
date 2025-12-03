{lib, ...}: let
  inherit (lib) mkDefault;
in {
  imports = [
    ./options.nix
    ./config.nix
  ];

  config.networking.nameservers = mkDefault [
    "1.1.1.1"
    "1.0.0.1"
  ];
}
