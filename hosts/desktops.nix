let
  presets = import ../system/display/presets.nix;
in {
  deimos = presets.integrated;
  phobos = presets.integrated;
}
