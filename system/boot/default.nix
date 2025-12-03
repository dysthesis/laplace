{
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    mkDefault
    mkOption
    ;
  inherit
    (lib.types)
    enum
    ;
  inherit (lib.babel.path) getDirectories;
  inherit (lib.babel.modules) importInDirectory;
  options = (getDirectories ./.) ++ ["none"];
in {
  config.boot = {
    initrd.verbose = mkDefault false;
    tmp = {
      useTmpfs = true;
      cleanOnBoot = mkDefault (!config.boot.tmp.useTmpfs);
    };
  };
  options.laplace.bootloader = mkOption {
    type = enum options;
    description = "Which bootloader to use";
    default = "none";
  };
  imports = importInDirectory ./.;
}
