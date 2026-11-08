# The kernel and hardened patch must have the same release number.
final: prev: let
  version = "7.3.1";
  suffix = "hardened1";
  modDirVersion = "${prev.lib.versions.pad 3 version}-${suffix}";

  base = prev.linux_latest;
  src = prev.fetchurl {
    url = "mirror://kernel/linux/kernel/v7.x/linux-${version}.tar.xz";
    hash = "sha256-+llarZNzT4KcljwqkO98NnMiT9f9rntJQG45fN4t4jE=";
  };

  hardenedPatch = {
    name = "linux-hardened-v${version}-${suffix}";
    patch = prev.fetchurl {
      url = "https://github.com/anthraxx/linux-hardened/releases/download/v${version}-${suffix}/linux-hardened-v${version}-${suffix}.patch";
      hash = "sha256-x5yDZN/T5qQmjx38bpsiDJR3bWqs4KbWHc4TXcv66tg=";
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
