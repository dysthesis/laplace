{
  boot = {
    initrd.availableKernelModules = [
      "xhci_pci"
      "usbhid"
      "usb_storage"
    ];

    initrd.kernelModules = [ ];
    kernelModules = [
      "kvm-amd"
      "uinput"
    ];
    extraModulePackages = [ ];
  };
}
