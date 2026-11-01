let
  inherit (builtins) mapAttrs;
in {
  disko.devices = {
    disk.main = {
      device = "/dev/nvme0n1";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";

            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = ["defaults"];
            };
          };

          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot";
              passwordFile = "/tmp/luks.key";
              settings.allowDiscards = true;

              content = {
                type = "btrfs";
                extraArgs = ["-f"];

                subvolumes = let
                  mountOptions = [
                    "defaults"
                    "ssd"
                    "noatime"
                    "compress=zstd"
                    "space_cache=v2"
                    "discard=async"
                    "autodefrag"
                  ];
                in
                  mapAttrs (_name: value: value // {inherit mountOptions;}) {
                    "@persist".mountpoint = "/nix/persist";
                    "@home".mountpoint = "/home";
                  }
                  // {
                    "@nix" = {
                      mountpoint = "/nix";
                      inherit mountOptions;
                    };
                    "@swap" = {
                      mountpoint = "/swap";
                      swap.swapfile.size = "8G";
                    };
                  };
              };
            };
          };
        };
      };
    };

    nodev = let
      mountOptions = [
        "size=2G"
        "defaults"
        "mode=755"
      ];
    in {
      "/" = {
        fsType = "tmpfs";
        inherit mountOptions;
      };
    };
  };

  # Mount /nix/persist in the initrd for mnemosyne's first-boot directory creation.
  # SOPS must use this mount if its age key is in /nix/persist.
  # See deimos/disks.nix and the proxmox profile.
  fileSystems."/nix/persist".neededForBoot = true;
}
