{lib, ...}: let
  data = import ./data.nix;
  transforms = import ./transforms.nix {inherit lib;};
  spawnBind = combo: title: command: args: {
    inherit combo title;
    actions = [
      {
        type = "spawn";
        inherit command args;
      }
    ];
  };
in {
  mkModel = context: let
    desktop = context.desktop or {enable = false;};
    palette = desktop.palette;
    settings =
      if !desktop.enable
      then data
      else
        data
        // {
          cursor = data.cursor // {xcursorSize = 24;};
          blur.off = true;
          layout =
            data.layout
            // {
              gaps = 10;
              focusRing = {
                width = 1;
                activeColor = palette.focus;
                inactiveColor = palette.border;
              };
              tabIndicator =
                data.layout.tabIndicator
                // {
                  activeColor = palette.focus;
                  inactiveColor = palette.border;
                  urgentColor = palette.urgent;
                };
            };
          windowRules =
            lib.filter (
              rule:
                !(lib.any (match: (match.appId or null) == "^foot$") (rule.matches or [])
                  && (rule.backgroundEffect.blur or false))
            )
            data.windowRules;
          binds =
            map (
              bind:
                if bind.combo == "Mod+R"
                then spawnBind "Mod+R" "Launch an application" "launcher" ["toggle"]
                else if bind.combo == "Mod+V"
                then bind // {combo = "Mod+Ctrl+V";}
                else bind
            )
            data.binds
            ++ [
              (spawnBind "Mod+Space" "Launch an application" "launcher" ["toggle"])
              (spawnBind "Mod+V" "Clipboard history" "launcher" ["vicinae://launch/clipboard/history"])
              (spawnBind "Mod+N" "Notifications" "quickshell" ["ipc" "call" "desktop" "toggleNotifications"])
              (spawnBind "Mod+Shift+N" "Toggle quiet mode" "quickshell" ["ipc" "call" "desktop" "toggleQuiet"])
            ];
        };
    binds = map (transforms.resolveBind context.deps) settings.binds;
    startup = map (transforms.resolveStartup context.deps) settings.startup;
    outputs = map transforms.monitorToOutput context.monitors;
  in
    transforms.validateModel {
      inherit
        binds
        outputs
        startup
        ;
      inherit
        (settings)
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
