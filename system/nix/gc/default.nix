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

    # Retain the daily seven-day generation policy with a single collector.
    environment.etc."determinate/config.json" = lib.mkIf config.determinate.enable {
      text = builtins.toJSON {
        garbageCollector.strategy = "disabled";
      };
    };
  };
}
