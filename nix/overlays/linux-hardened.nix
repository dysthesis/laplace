# The kernel and hardened patch must have the same release number.
final: prev: let
  version = "7.2.5";
  suffix = "hardened1";
  modDirVersion = "${prev.lib.versions.pad 3 version}-${suffix}";

  base = prev.linux_latest;
  src = prev.fetchurl {
    url = "mirror://kernel/linux/kernel/v7.x/linux-${version}.tar.xz";
    hash = "sha256-Vd3w34Ml2drZb8/3vZOXfSLj9QrwZSdXKvWbd8djK3g=";
  };

  hardenedPatch = {
    name = "linux-hardened-v${version}-${suffix}";
    patch = prev.fetchurl {
      url = "https://github.com/anthraxx/linux-hardened/releases/download/v${version}-${suffix}/linux-hardened-v${version}-${suffix}.patch";
      hash = "sha256-yB4ip+GEzLrX5V7qG1dKrmka9M20QVrnnMas7q0Ug14=";
    };
  };

  linuxHardened = base.override {
    kernelPatches = base.kernelPatches ++ [hardenedPatch];
    structuredExtraConfig = import ../linux-hardened/config.nix {
      inherit (prev) lib stdenv;
      inherit version;
    };
    # modDirVersion must match the padded release and patch suffix for modules to load.
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
