{lib, ...}: let
  inherit
    (lib.laplace.modules)
    fromDirectories
    enableOptsFromDir
    ;
in {
  options.laplace.features.hardening = enableOptsFromDir ./. "Whether or not to enable hardening for the";

  imports =
    map
    (name: "${./.}/${name}")
    (fromDirectories ./.);
}
