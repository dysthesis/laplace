final: prev: let
  version = "7.0.10";
  suffix = "hardened1";

  hardenedPatch = {
    name = "linux-hardened-v${version}-${suffix}";
    patch = prev.fetchurl {
      url = "https://github.com/anthraxx/linux-hardened/releases/download/v${version}-${suffix}/linux-hardened-v${version}-${suffix}.patch";
      hash = "sha256-rBaLEkxFPxyRYNTxaiTLfMykJt8UBtlajNVxGDUNmFw=";
    };
  };

  linuxHardened = prev.linux_7_0.override {
    kernelPatches = prev.linux_7_0.kernelPatches ++ [hardenedPatch];
    structuredExtraConfig = import ../linux-hardened/config.nix {
      inherit (prev) lib stdenv;
      inherit version;
    };
    argsOverride = {
      inherit version;
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
