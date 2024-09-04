{lib, ...}: let
  inherit (lib) mkForce;
in {
  # No default packages. From https://xeiaso.net/blog/paranoid-nixos-2021-07-18/
  environment.defaultPackages = mkForce [];
  imports = [
    ./hardware
    ./boot
    ./network
    ./nix
    ./security
    ./sound
    ./users
  ];
}
