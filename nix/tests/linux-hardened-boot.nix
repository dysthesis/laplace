# The QEMU guest uses the production kernel with a test initrd.
{pkgs}: let
  kernel = pkgs.linuxPackages_hardened.kernel;
  # Use the modules from system/profiles/proxmox/default.nix.
  availableModules = [
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
    "virtio_net"
    "uas"
    "sd_mod"
  ];
  earlyModules = [
    "virtio_balloon"
    "virtio_console"
    "virtio_rng"
  ];
  modules = availableModules ++ earlyModules ++ ["btrfs"];
in
  pkgs.testers.runNixOSTest {
    name = "linux-hardened-boot";

    nodes.machine = {config, ...}: {
      boot = {
        kernelPackages = pkgs.linuxPackages_hardened;
        supportedFilesystems = ["btrfs"];
        initrd = {
          # The ext4 test root does not cause the initrd to include Btrfs.
          supportedFilesystems = ["btrfs"];
          availableKernelModules = availableModules;
          kernelModules = earlyModules;
          systemd.enable = true;
        };
      };
      # The driver must connect to stage 1 before it starts stage 2.
      testing.initrdBackdoor = true;
      assertions = [
        {
          assertion = config.boot.kernelPackages.kernel.drvPath == kernel.drvPath;
          message = "The boot smoke test must reuse the exact hardened kernel, without test-only config changes.";
        }
      ];
    };

    testScript = ''
      machine.start()
      machine.wait_for_unit("initrd.target")
      machine.succeed("test -e /etc/initrd-release")
      machine.succeed("test \"$(cat /proc/1/comm)\" = systemd")
      print(machine.succeed("uname -r"))
      machine.succeed("test \"$(uname -r)\" = '${kernel.modDirVersion}'")

      machine.succeed("modprobe -a ${pkgs.lib.concatStringsSep " " modules}")
      machine.succeed("test ! -e /proc/kcore")

      machine.switch_root()
      machine.wait_for_unit("multi-user.target")
      machine.succeed("test ! -e /etc/initrd-release")
      machine.succeed("test \"$(cat /proc/1/comm)\" = systemd")
      machine.succeed("test \"$(uname -r)\" = '${kernel.modDirVersion}'")
      machine.succeed("modprobe -a ${pkgs.lib.concatStringsSep " " modules}")

      machine.succeed("test ! -e /proc/kcore")
    '';
  }
