{lib, ...}: let
  inherit (lib.laplace.options) mkEnumOption;
  elems = ["amd"];
in {
  options.laplace.hardware.cpu = mkEnumOption {
    inherit elems;
    # I only have AMD  devices
    description = "The manufaturer of the CPU";
  };

  imports = map (x: "${./.}/${x}/") elems;
}
