{
  lib,
  config,
  ...
}: let
  inherit (lib) mkIf;
  inherit (builtins) elem;
  cfg = config.laplace.harden;
  isDesktop = elem "desktop" config.laplace.profiles;
in {
  config = mkIf (elem "malloc" cfg) {
    environment = {
      memoryAllocator.provider = "graphene-hardened";
      variables.SCUDO_OPTIONS = "ZeroContents=1";
    };
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
