{
  lib,
  config,
  ...
}: let
  inherit
    (lib.laplace.options)
    mkEnumOption
    mkEnumListOption
    ;

  inherit (lib.laplace.modules) importInDirectory fromDirectories;

  elems = fromDirectories ./.;
in {
  options.laplace.rootFilesystem = mkEnumOption {
    inherit elems;
    description = "The type of filesystem to use as root";
  };

  options.laplace.filesystems = mkEnumListOption {
    inherit elems;
    description = "Which filesystems to enable support for";
    default = [config.laplace.rootFilesystem];
  };

  imports = importInDirectory ./.;
}
