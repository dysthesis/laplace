{
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "usbhid"
    "usb_storage"
  ];
  boot.initrd.kernelModules = [];
  boot.kernelModules = [
    "kvm-amd"
    "uinput"
  ];
  boot.extraModulePackages = [];
}
