{
  lib,
  config,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  inherit (builtins) elem;
  cfg = config.laplace.harden;
  isDesktop = elem "desktop" config.laplace.profiles;
in {
  config = mkIf (elem "malloc" cfg) {
    environment.memoryAllocator.provider = "graphene-hardened";
    boot.kernel.sysctl."vm.max_map_count" = 1048576;
    systemd.services.redis-immich.environment.LD_PRELOAD =
      lib.mkForce "${pkgs.jemalloc}/lib/libjemalloc.so";
    nixpkgs.overlays = lib.optional isDesktop (_final: prev: {
      graphene-hardened-malloc = prev.graphene-hardened-malloc.overrideAttrs (old: {
        # C++ interposition crashes Gecko/Mesa; normal new/delete still use malloc.
        makeFlags = (old.makeFlags or []) ++ ["CONFIG_CXX_ALLOCATOR=false"];
        # glibc's sized-free wrapper dispatches to the owning free, including PartitionAlloc.
        NIX_LDFLAGS =
          (old.NIX_LDFLAGS or "")
          + " --version-script=${prev.writeText "malloc-exports.map" "{ local: free_sized; };"}";
      });
    });
  };
}
