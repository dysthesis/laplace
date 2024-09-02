{lib, ...}: let
  inherit (lib.laplace.options) mkEnumOption;
in {
  options.laplace.hardware.cpu = mkEnumOption {
    # I only have AMD  devices
    elems = ["amd"];
    description = "The manufaturer of the CPU";
  };

  imports = [
    ./amd
  ];
}
