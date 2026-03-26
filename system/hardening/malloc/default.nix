{
  lib,
  config,
  ...
}: let
  inherit (lib) mkIf;
  inherit (builtins) elem;
  cfg = config.laplace.harden;
in {
  config = mkIf (elem "malloc" cfg) {
    environment = {
      # NixOS enables this allocator globally via /etc/ld-nix.so.preload.
      # Zen already ships with --enable-replace-malloc, but on AMD systems it
      # can still crash later in the Mesa/LLVM radeonsi path under
      # hardened_malloc, so the Zen wrapper forces Zink instead.
      memoryAllocator.provider = "graphene-hardened";
      variables.SCUDO_OPTIONS = "ZeroContents=1";
    };
  };
}
