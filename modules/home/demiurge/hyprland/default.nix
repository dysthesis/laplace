{
  systemConfig,
  lib,
  ...
}: let
  inherit
    (builtins)
    readDir
    attrNames
    ;
  inherit
    (lib)
    filter
    hasSuffix
    filterAttrs
    ;
in {
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      monitors =
        map (
          monitor: let
            resolution = "${toString monitor.width}x${toString monitor.height}@${toString monitor.refreshRate}";
            position = "${toString monitor.pos.x}x${toString monitor.pos.y}";
          in "${monitor.name},${
            if monitor.enabled
            then "${resolution},${position},1"
            else "disable"
          }"
        )
        systemConfig.laplace.hardware.monitors;

      xwayland.force_zero_scaling = true;

      general = {
        gaps_in = 4;
        gaps_out = 8;

        border_size = 2;

        layout = "master";
        "col.active_border" = "rgb(ffffff)";

        apply_sens_to_raw = 0;
      };
    };
  };
  # Import all Nix files in the current directory
  imports = let
    inCwd = filterAttrs isFile (readDir ./.);
    isNixFile = file: hasSuffix ".nix" file;
    isFile = _: value: value == "regular";
  in
    map
    (file: ./${file})
    (filter
      (name: name != "default.nix" && isNixFile name)
      (attrNames inCwd));
}
