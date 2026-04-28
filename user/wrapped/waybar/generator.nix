{
  pkgs,
  lib,
  hostName,
  monitors,
  settings,
  weather,
}: let
  inherit
    (lib)
    concatStringsSep
    findFirst
    hasPrefix
    mapAttrsToList
    max
    min
    ;

  concatMap = f: values: builtins.concatLists (map f values);

  defaultMonitor =
    if monitors == []
    then {
      width = 1920;
      height = 1080;
    }
    else builtins.head monitors;

  primaryMonitor = findFirst (monitor: monitor.primary or false) defaultMonitor monitors;

  clamp = lower: upper: value:
    max lower (min upper value);

  round = value: builtins.floor (value + 0.5);

  monitorHeight = primaryMonitor.height or settings.scale.baselineHeight;
  rawScale =
    if monitorHeight > 0
    then settings.scale.baselineHeight / monitorHeight
    else throw "Waybar primary monitor height must be positive";
  scale = clamp settings.scale.min settings.scale.max rawScale;

  scaleMetric = metric: let
    minimum = metric.min or 0;
  in
    max minimum (round (metric.base * scale));

  metrics = builtins.mapAttrs (_: scaleMetric) settings.theme.metrics;

  baseHeight =
    if builtins.isAttrs settings.bar.baseHeight
    then settings.bar.baseHeight.${hostName} or settings.bar.baseHeight.default
    else settings.bar.baseHeight;

  bar = {
    inherit
      (settings.bar)
      layer
      position
      exclusive
      passthrough
      ;
    mod = settings.bar.mode;
    height = round (baseHeight * scale);
    gtk-layer-shell = settings.bar.gtkLayerShell;
  };

  mkStaticModule = format: {
    inherit format;
    interval = "once";
    tooltip = false;
  };

  generatedModules = {
    "custom/l_end" = mkStaticModule " ";
    "custom/r_end" = mkStaticModule " ";
    "custom/sl_end" = mkStaticModule " ";
    "custom/sr_end" = mkStaticModule " ";
    "custom/rl_end" = mkStaticModule " ";
    "custom/rr_end" = mkStaticModule " ";
    "custom/padd" = mkStaticModule "  ";
  };

  weatherModules =
    if settings.weather.enable
    then {
      "custom/weather" = {
        tooltip = true;
        format = "{} ";
        interval = settings.weather.interval;
        exec = "${weather}/bin/weather waybar ${settings.weather.productId}";
        return-type = "json";
      };
    }
    else {};

  configuredModules = generatedModules // weatherModules // settings.modules;

  modules =
    configuredModules
    // {
      battery = (configuredModules.battery or {}) // {bat = settings.hardware.battery;};
      backlight = (configuredModules.backlight or {}) // {device = settings.hardware.backlight;};
    };

  normaliseSection = section:
    if builtins.isList section
    then {
      groups = section;
      before = [];
      after = [];
    }
    else {
      groups = section.groups or [];
      before = section.before or [];
      after = section.after or [];
    };

  mkPill = group: [settings.layout.cap.left] ++ group ++ [settings.layout.cap.right];

  mkSection = section: let
    section' = normaliseSection section;
  in
    [settings.layout.padding]
    ++ section'.before
    ++ concatMap mkPill section'.groups
    ++ section'.after
    ++ [settings.layout.padding];

  sectionNames = section: let
    section' = normaliseSection section;
  in
    section'.before ++ concatMap (group: group) section'.groups ++ section'.after;

  layout = {
    left = mkSection settings.layout.left;
    center = mkSection settings.layout.center;
    right = mkSection settings.layout.right;
  };

  layoutModuleNames =
    sectionNames settings.layout.left
    ++ sectionNames settings.layout.center
    ++ sectionNames settings.layout.right;

  missingCustomModules =
    builtins.filter (
      name:
        name
        != ""
        && hasPrefix "custom/" name
        && !(builtins.hasAttr name modules)
    )
    layoutModuleNames;

  validWeatherProductId =
    !settings.weather.enable
    || builtins.match "IDN[0-9][0-9][0-9][0-9][0-9]" settings.weather.productId != null;

  model =
    if settings.scale.min > settings.scale.max
    then throw "Waybar scale.min must be less than or equal to scale.max"
    else if !(baseHeight > 0)
    then throw "Waybar bar.baseHeight must be positive"
    else if !validWeatherProductId
    then throw "Waybar weather.productId must match IDNxxxxx"
    else if missingCustomModules != []
    then throw "Waybar layout references missing custom modules: ${concatStringsSep ", " missingCustomModules}"
    else {
      inherit
        bar
        layout
        modules
        metrics
        ;
      theme = settings.theme;
    };

  waybarConfig =
    model.bar
    // {
      modules-left = model.layout.left;
      modules-center = model.layout.center;
      modules-right = model.layout.right;
    }
    // model.modules
    // settings.rawSettings;

  jsonFormat = pkgs.formats.json {};

  colorDefinitions =
    model.theme.colors
    |> mapAttrsToList (name: value: "    @define-color ${name} ${value};")
    |> concatStringsSep "\n";

  moduleSelectors =
    model.theme.selectors.modules
    |> map (selector: "    #${selector}")
    |> concatStringsSep ",\n";

  css = let
    m = model.metrics;
    inherit (model.theme) font;
  in
    pkgs.writeText "waybar-style.css"
    # css
    ''
            * {
                border: none;
                border-radius: 0px;
                font-family: "${font.family}";
                font-weight: ${font.weight};
                font-size: ${toString m.size}px;
                min-height: ${toString m.size}px;
            }

      ${colorDefinitions}

            window#waybar {
                background: @bar-bg;
            }

            tooltip {
                background: @tool-bg;
                color: @tool-color;
                border-radius: ${toString m.rLarge}px;
                border-width: 1px;
                border-style: solid;
                border-color: @tool-border;
            }

            #workspaces button {
                box-shadow: none;
                text-shadow: none;
                padding: 0px;
                border-radius: ${toString m.rMed}px;
                margin-top: ${toString m.margin}px;
                margin-bottom: ${toString m.margin}px;
                padding-left: ${toString m.padS}px;
                padding-right: ${toString m.padS}px;
                color: @wb-color;
                animation: gradient_f 20s ease-in infinite;
                transition: all 0.5s cubic-bezier(.55,-0.68,.48,1.682);
            }

            #workspaces button.active,
            #workspaces button.focused {
                background: @wb-act-bg;
                color: @wb-act-color;
                margin-left: ${toString m.margin}px;
                padding-left: ${toString m.size}px;
                padding-right: ${toString m.size}px;
                margin-right: ${toString m.margin}px;
                animation: gradient_f 20s ease-in infinite;
                transition: all 0.3s cubic-bezier(.55,-0.68,.48,1.682);
            }

            #workspaces button:hover {
                background: @wb-hvr-bg;
                color: @wb-hvr-color;
                padding-left: ${toString m.padS}px;
                padding-right: ${toString m.padS}px;
                animation: gradient_f 20s ease-in infinite;
                transition: all 0.3s cubic-bezier(.55,-0.68,.48,1.682);
            }

            #taskbar button {
                box-shadow: none;
                text-shadow: none;
                padding: 0px;
                border-radius: ${toString m.rSmall}px;
                margin-top: ${toString m.margin}px;
                margin-bottom: ${toString m.margin}px;
                padding-left: ${toString m.padS}px;
                padding-right: ${toString m.padS}px;
                color: @wb-color;
                animation: gradient_f 20s ease-in infinite;
                transition: all 0.5s cubic-bezier(.55,-0.68,.48,1.682);
            }

            #taskbar button.active {
                background: @wb-act-bg;
                color: @wb-act-color;
                margin-left: ${toString m.margin}px;
                padding-left: ${toString m.padActive}px;
                padding-right: ${toString m.padActive}px;
                margin-right: ${toString m.margin}px;
                animation: gradient_f 20s ease-in infinite;
                transition: all 0.3s cubic-bezier(.55,-0.68,.48,1.682);
            }

            #taskbar button:hover {
                background: @wb-hvr-bg;
                color: @wb-hvr-color;
                padding-left: ${toString m.padS}px;
                padding-right: ${toString m.padS}px;
                animation: gradient_f 20s ease-in infinite;
                transition: all 0.3s cubic-bezier(.55,-0.68,.48,1.682);
            }

      ${moduleSelectors} {
                color: @main-color;
                background: @main-bg;
                opacity: 1;
                margin: ${toString m.modVMargin}px 0px ${toString m.modVMargin}px 0px;
                padding-left: ${toString m.padM}px;
                padding-right: ${toString m.padM}px;
            }

            #workspaces,
            #taskbar {
                padding: 0px;
            }

            #custom-r_end {
                border-radius: 0px ${toString m.rLarge}px ${toString m.rLarge}px 0px;
                margin-right: ${toString m.margin}px;
                padding-right: ${toString m.padS}px;
            }

            #custom-l_end {
                border-radius: ${toString m.rLarge}px 0px 0px ${toString m.rLarge}px;
                margin-left: ${toString m.margin}px;
                padding-left: ${toString m.padS}px;
            }

            #custom-sr_end {
                border-radius: 0px;
                margin-right: ${toString m.margin}px;
                padding-right: ${toString m.padS}px;
            }

            #custom-sl_end {
                border-radius: 0px;
                margin-left: ${toString m.margin}px;
                padding-left: ${toString m.padS}px;
            }

            #custom-rr_end {
                border-radius: 0px ${toString m.rTiny}px ${toString m.rTiny}px 0px;
                margin-right: ${toString m.margin}px;
                padding-right: ${toString m.padS}px;
            }

            #custom-rl_end {
                border-radius: ${toString m.rTiny}px 0px 0px ${toString m.rTiny}px;
                margin-left: ${toString m.margin}px;
                padding-left: ${toString m.padS}px;
            }

      ${model.theme.extraCss}
    '';
in {
  json = jsonFormat.generate "waybar-config.json" waybarConfig;
  inherit css;
}
