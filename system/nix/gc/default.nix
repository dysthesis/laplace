{
  config,
  lib,
  ...
}: {
  config = {
    nix.gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 7d";
    };

    # Disable the Determinate collector to prevent duplicate garbage collection.
    environment.etc."determinate/config.json" = lib.mkIf config.determinate.enable {
      text = builtins.toJSON {
        garbageCollector.strategy = "disabled";
      };
    };
  };
}
