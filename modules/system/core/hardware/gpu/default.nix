{lib, ...}: let
  inherit (lib.laplace.options) mkEnumOption;
in {
  options.laplace.hardware.gpu = mkEnumOption {
    # I only have AMD  devices
    elems = ["amd"];
    description = "The manufaturer of the GPU";
  };

  imports = [
    ./amd
  ];
}
