{
  lib,
  config,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (builtins) elem;
  cfg = config.laplace.filesystems;
in
{
  config = mkIf (elem "btrfs" cfg) {
    services.btrfs.autoScrub = {
      enable = true;
      interval = "weekly";
    };
  };
}
