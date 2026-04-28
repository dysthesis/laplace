{lib, ...}: let
  data = import ./data.nix;
  transforms = import ./transforms.nix {inherit lib;};
in {
  mkModel = context: let
    binds = map (transforms.resolveBind context.deps) data.binds;
    startup =
      map (transforms.resolveStartup context.deps) data.startup
      ++ transforms.locationToStartup context;
    outputs = map transforms.monitorToOutput context.monitors;
  in
    transforms.validateModel {
      inherit
        binds
        outputs
        startup
        ;
      inherit
        (data)
        environment
        cursor
        input
        screenshotPath
        layout
        preferNoCsd
        blur
        hotkeyOverlay
        windowRules
        ;
      xwaylandSatellite = context.deps.xwaylandSatellite;
    };
}
