{lib, ...}: let
  inherit (builtins) mapAttrs;
  inherit (lib) fold;
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
            # Use the rest of the disk
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
                    "@nix".mountpoint = "/nix";
                    "@persist".mountpoint = "/nix/persist";
                  }
                  // {
                    "@swap" = {
                      mountpoint = "/swap";
                      swap.swapfile.size = "4G";
                    };
                  };
              };
            };
          };
        };
      };
    };

    # Make root and home impermanent
    nodev =
      fold (curr: acc:
        acc
        // {
          "${curr}" = {
            fsType = "tmpfs";
            mountOptions = [
              "size=4G"
              "defaults"
              "mode=755"

              # WARN: This may break stuff
              # Disable the execution of anything outside the Nix store
              "noexec"
            ];
          };
        })
      {}
      [
        "/"
        "/home"
      ];
  };
}
