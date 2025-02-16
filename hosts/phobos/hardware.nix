{
  inputs,
  config,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    inputs.nixos-hardware.nixosModules.framework-13-7040-amd
  ];

  boot.initrd.availableKernelModules =
    [
      "nvme"
      "xhci_pci"
      "thunderbolt"
      "usb_storage"
      "sd_mod"
      "dm_mod"
      "dm_crypt"
      "cryptd"
      # Try to fix wifi connectiion with NetworkManager
      "ccm"
      "ctr"
    ]
    ++ config.boot.initrd.luks.cryptoModules;
  boot.initrd.kernelModules = [];
  boot.kernelModules = [
    "kvm-amd"
    "uinput"
  ];
  boot.extraModulePackages = [];
}
