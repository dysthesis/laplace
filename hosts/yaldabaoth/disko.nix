{
  disko.devices.disk = {
    main = {
      type = "disk";
      device = "/dev/nvme0n1";
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
              # TODO: Use a passwordFile encrypted with sops-nix or agenix
              # passwordFile = "/tmp/secrets.key"
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
                  # subvolumes = [
                  #   { name = "@"; mountpoint = "/"; }
                  # ];
                in {
                  # Root subvolume
                  "@" = {
                    mountpoint = "/";
                    inherit mountOptions;
                  };
                  "@home" = {
                    mountpoint = "/home";
                    inherit mountOptions;
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    inherit mountOptions;
                  };
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
  };
}
