{lib, ...}: let
  inherit (lib) mkEnableOption;
  inherit (lib.laplace.options) mkEnumOption;
  elems = ["pipewire"];
in {
  options.laplace.sound = {
    enable = mkEnableOption "Enable sound server.";
    server = mkEnumOption {
      inherit elems;
      description = "Which sound server to use";
    };
  };

  imports = map (x: "${./.}/${x}/") elems;
}
