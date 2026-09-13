# linux-hardened kernel overlay.
# Applies the upstream linux-hardened patch and local config to linux_latest.
# Pin the exact kernel release because hardened patches do not follow moving branches.
final: prev: let
  version = "7.2.5";
  suffix = "hardened1";
  modDirVersion = "${prev.lib.versions.pad 3 version}-${suffix}";

  base = prev.linux_latest;
  src = prev.fetchurl {
    url = "mirror://kernel/linux/kernel/v7.x/linux-${version}.tar.xz";
    hash = "sha256-aR9EeX++eQ3IoyFgTJJwh1Jq0nttZJkl1g+O7QolZKA=";
  };

  hardenedPatch = {
    name = "linux-hardened-v${version}-${suffix}";
    patch = prev.fetchurl {
      url = "https://github.com/anthraxx/linux-hardened/releases/download/v${version}-${suffix}/linux-hardened-v${version}-${suffix}.patch";
      hash = "sha256-VpzjHXkuiPra4yMLD9KYUUh8cyK00xwZ9V1gBILcIxI=";
    };
  };

  linuxHardened = base.override {
    kernelPatches = base.kernelPatches ++ [hardenedPatch];
    structuredExtraConfig = import ../linux-hardened/config.nix {
      inherit (prev) lib stdenv;
      inherit version;
    };
    # The patch sets EXTRAVERSION=-hardened1. Nixpkgs pads 7.1 to 7.1.0,
    # so modDirVersion must include the padded release or modules will not load.
    argsOverride = {
      pname = "linux-hardened";
      inherit src version modDirVersion;
    };
    extraPassthru.isHardened = true;
  };
in {
  linux_latest_hardened = linuxHardened;
  linux_hardened = linuxHardened;

  linuxPackages_latest_hardened = final.linuxPackagesFor final.linux_latest_hardened;
  linuxPackages_hardened = final.linuxPackages_latest_hardened;
}
