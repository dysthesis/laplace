{
  inputs,
  config,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    inputs.nixos-hardware.nixosModules.framework-13-7040-amd
  ];

  boot = {
    initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "thunderbolt"
      "usb_storage"
      "sd_mod"
      "dm_mod"
      "dm_crypt"
      "cryptd"
      "ccm"
      "ctr"
    ] ++ config.boot.initrd.luks.cryptoModules;
    initrd.kernelModules = [ ];
    kernelModules = [
      "kvm-amd"
      "uinput"
    ];
    extraModulePackages = [ ];
  };
}
