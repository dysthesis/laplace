{
  lib,
  config,
  ...
}: let
  inherit (lib.laplace.options) mkEnumOption mkEnumListOption;
  filesystems = ["btrfs"];
in {
  options.laplace.rootFilesystem = mkEnumOption {
    elems = filesystems;
    description = "The type of filesystem to use as root";
  };

  options.laplace.filesystems = mkEnumListOption {
    elems = filesystems;
    description = "Which filesystems to enable support for";
    default = [config.laplace.rootFilesystem];
  };

  imports = map (filesystem: ./${filesystem}) filesystems;
}
