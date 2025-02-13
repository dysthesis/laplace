let
  inherit (builtins) mapAttrs;
in
{
  disko.devices = {
    disk.main = {
      device = "/dev/sda";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            name = "boot";
            size = "1M";
            type = "EF02";
          };

          ESP = {
            size = "1G";
            type = "EF00";

            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "defaults" ];
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
                extraArgs = [ "-f" ];

                subvolumes =
                  let
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
                  mapAttrs (_name: value: value // { inherit mountOptions; }) {
                    "@nix".mountpoint = "/nix";
                    "@persist".mountpoint = "/nix/persist";
                    "@home".mountpoint = "/home";
                  }
                  // {
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

    # Make root impermanent
    nodev = {
      "/" = {
        fsType = "tmpfs";
        mountOptions = [
          "size=2G"
          "defaults"
          "mode=755"
        ];
      };
    };
  };
}
