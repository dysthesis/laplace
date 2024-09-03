{lib, ...}: let
  inherit (lib.laplace.options) mkEnumOption;
  elems = ["amd"];
in {
  options.laplace.hardware.gpu = mkEnumOption {
    # I only have AMD  devices
    inherit elems;
    description = "The manufaturer of the GPU";
  };

  imports = map (x: "${./.}/${x}/") elems;
}
