{
  lib,
  config,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  networking.interfaces.eth0.useDHCP = true;

  # https://lantian.pub/en/article/modify-computer/nixos-low-ram-vps.lantian/
  boot = {
    initrd = {
      availableKernelModules =
        [
          "ahci"
          "xhci_pci"
          "virtio_net"
          "virtio_pci"
          "virtio_scsi"
          "virtio_mmio"
          "virtio_blk"
          "sd_mod"
          "sr_mod"
          "dm_mod"
          "dm_crypt"
          "cryptd"
        ]
        ++ config.boot.initrd.luks.cryptoModules;

      kernelModules = [
        "virtio_balloon"
        "virtio_console"
        "virtio_rng"
      ];
    };

    kernelParams = [
      "audit=0"
      # Do not generate NIC names based on PCIe addresses (e.g. enp1s0, useless for VPS)
      # Generate names based on orders (e.g. eth0)
      "net.ifnames=0"
    ];

    initrd = {
      compressor = "zstd";
      compressorArgs = ["-19" "-T0"];
      # Kernel modules required by QEMU (KVM) virtual machine
      postDeviceCommands =
        lib.mkIf (!config.boot.initrd.systemd.enable)
        /*
        sh
        */
        ''
          # Set the system time from the hardware clock to work around a
          # bug in qemu-kvm > 1.5.2 (where the VM clock is initialised
          # to the *boot time* of the host).
          hwclock -s
        '';
    };
  };

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  # networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp1s0.useDHCP = lib.mkDefault true;
}
