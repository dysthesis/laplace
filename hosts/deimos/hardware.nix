{
  config,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot = {
    initrd = {
      availableKernelModules =
        [
          "nvme"
          "xhci_pci"
          "ahci"
          "usb_storage"
          "usbhid"
          "uas"
          "sd_mod"
          "dm_mod"
          "dm_crypt"
          "cryptd"
        ]
        ++ config.boot.initrd.luks.cryptoModules;
      kernelModules = [];
    };
    kernelModules = [
      "kvm-amd"
      "uinput"
    ];
    extraModulePackages = [];
  };
}
