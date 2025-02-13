{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  cfg = config.laplace.sound.enable && config.laplace.sound.server == "pipewire";
in
{
  config = mkIf cfg {
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      wireplumber.enable = true;
      pulse.enable = true;
      jack.enable = true;
    };
  };
}
