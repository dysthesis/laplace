# linux-hardened kernel overlay.
#
# nixpkgs dropped its own `linux_hardened` (removed 2025-10-01, lack of
# maintenance), so this overlay is now the sole source of a hardened kernel
# here. We take nixpkgs' plain `linux_7_0` and layer the upstream
# linux-hardened patch + the curated hardening config (../linux-hardened/
# config.nix) on top.
#
# The hardened patch is cut against one exact upstream tarball, so its hunks
# only apply to that kernel point release. Rather than re-pin the kernel
# source (a second hash to keep in sync), we reuse nixpkgs' linux_7_0 source
# and assert it is still the release the patch targets.
#
# simplification: this couples us to nixpkgs tracking 7.0.12. The assertion
# turns a future drift (e.g. nixpkgs bumping linux_7_0 to 7.0.13) into a clear
# eval error naming what to bump, instead of a cryptic patch-hunk failure deep
# in the kernel build. Upgrade path on a new hardened release: bump `version`,
# refresh the patch `hash`, and let the assertion confirm the base matches.
final: prev: let
  version = "7.0.12";
  suffix = "hardened1";

  base = prev.linux_7_0;

  hardenedPatch = {
    name = "linux-hardened-v${version}-${suffix}";
    patch = prev.fetchurl {
      url = "https://github.com/anthraxx/linux-hardened/releases/download/v${version}-${suffix}/linux-hardened-v${version}-${suffix}.patch";
      hash = "sha256-TH7TYbGY/GrafKb2188lPC4RyB7hqv6lFMyP55oOWIc=";
    };
  };

  linuxHardened = assert prev.lib.assertMsg (base.version == version) ''
    linux-hardened: nixpkgs linux_7_0 is ${base.version}, but the pinned
    hardened patch targets ${version}. Bump `version` and the patch `hash`
    in nix/overlays/linux-hardened.nix (and check ../linux-hardened/config.nix).
  '';
    base.override {
      kernelPatches = base.kernelPatches ++ [hardenedPatch];
      structuredExtraConfig = import ../linux-hardened/config.nix {
        inherit (prev) lib stdenv;
        inherit version;
      };
      # No `version`/`src` override: we inherit linux_7_0's 7.0.12 source
      # (asserted above). The patch sets EXTRAVERSION=-hardened1, so the
      # kernel's release string becomes ${version}-${suffix}; modDirVersion
      # must equal it or modules will not load.
      argsOverride = {
        pname = "linux-hardened";
        modDirVersion = "${version}-${suffix}";
      };
      extraPassthru.isHardened = true;
    };
in {
  linux_7_0_hardened = linuxHardened;
  linux_hardened = linuxHardened;

  linuxPackages_7_0_hardened = final.linuxPackagesFor final.linux_7_0_hardened;
  linuxPackages_hardened = final.linuxPackages_7_0_hardened;
}
