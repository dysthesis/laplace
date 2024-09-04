{lib, ...}: let
  inherit (lib) mkEnableOption;
  inherit (lib.laplace.options) mkEnumOption;
  inherit
    (lib.laplace.modules)
    fromDirectories
    importInDirectory
    ;

  elems = fromDirectories ./.;
in {
  options.laplace.sound = {
    enable = mkEnableOption "Enable sound server.";
    server = mkEnumOption {
      inherit elems;
      description = "Which sound server to use";
    };
  };

  imports = importInDirectory ./.;
}
