{
  pkgs,
  config,
  lib,
  ...
}: let
  monitors = config.laplace.hardware.monitors or [];
  defaultMonitor =
    if monitors == []
    then {
      width = 1920;
      height = 1080;
    }
    else builtins.head monitors;
  primaryMonitor = lib.findFirst (m: (m.primary or false)) defaultMonitor monitors;

  clamp = min: max: val:
    lib.max min (lib.min max val);
  round = x: builtins.floor (x + 0.5);

  baselineH = 1080.0;
  rawScale = baselineH / (primaryMonitor.height or baselineH);
  scale = clamp 0.6 1.2 rawScale;

  baseSize = 9.0;
  baseMargin = 3.0;
  basePadS = 3.0;
  basePadM = 4.0;
  basePadActive = 12.0;
  baseModVMargin = 4.0;
  baseRLarge = 21.0;
  baseRMed = 16.0;
  baseRSmall = 9.0;
  baseRTiny = 7.0;

  calc = base: round (base * scale);

  size = calc baseSize;
  margin = lib.max 1 (calc baseMargin);
  padS = lib.max 1 (calc basePadS);
  padM = lib.max 1 (calc basePadM);
  padActive = lib.max 6 (calc basePadActive);
  modVMargin = lib.max 2 (calc baseModVMargin);
  rLarge = lib.max 8 (calc baseRLarge);
  rMed = lib.max 6 (calc baseRMed);
  rSmall = lib.max 5 (calc baseRSmall);
  rTiny = lib.max 4 (calc baseRTiny);
in
  pkgs.writeText "style.css"
  /*
  css
  */
  ''
    * {
        border: none;
        border-radius: 0px;
        font-family: "JBMono Nerd Font";
        font-weight: bold;
        font-size: ${toString size}px;
        min-height: ${toString size}px;
    }

    @define-color bar-bg rgba(0, 0, 0, 0.1);

    @define-color main-color #ffffff;
    @define-color main-bg #000000;

    @define-color tool-bg #1e1e2e;
    @define-color tool-color #7788AA;
    @define-color tool-border #000000;

    @define-color wb-color #7788AA;

    @define-color wb-act-bg #a6adc8;
    @define-color wb-act-color #313244;

    @define-color wb-hvr-bg #f5c2e7;
    @define-color wb-hvr-color #313244;

    window#waybar {
        background: @bar-bg;
    }

    tooltip {
        background: @tool-bg;
        color: @tool-color;
        border-radius: ${toString rLarge}px;
        border-width: 1px;
        border-style: solid;
        border-color: @tool-border;
    }

    #workspaces button {
        box-shadow: none;
    	  text-shadow: none;
        padding: 0px;
        border-radius: ${toString rMed}px;
        margin-top: ${toString margin}px;
        margin-bottom: ${toString margin}px;
        padding-left: ${toString padS}px;
        padding-right: ${toString padS}px;
        color: @wb-color;
        animation: gradient_f 20s ease-in infinite;
        transition: all 0.5s cubic-bezier(.55,-0.68,.48,1.682);
    }

    #workspaces button.active {
        background: @wb-act-bg;
        color: @wb-act-color;
        margin-left: ${toString margin}px;
        padding-left: ${toString size}px;
        padding-right: ${toString size}px;
        margin-right: ${toString margin}px;
        animation: gradient_f 20s ease-in infinite;
        transition: all 0.3s cubic-bezier(.55,-0.68,.48,1.682);
    }

    #workspaces button:hover {
        background: @wb-hvr-bg;
        color: @wb-hvr-color;
        padding-left: ${toString padS}px;
        padding-right: ${toString padS}px;
        animation: gradient_f 20s ease-in infinite;
        transition: all 0.3s cubic-bezier(.55,-0.68,.48,1.682);
    }

    #taskbar button {
        box-shadow: none;
    	  text-shadow: none;
        padding: 0px;
        border-radius: ${toString rSmall}px;
        margin-top: ${toString margin}px;
        margin-bottom: ${toString margin}px;
        padding-left: ${toString padS}px;
        padding-right: ${toString padS}px;
        color: @wb-color;
        animation: gradient_f 20s ease-in infinite;
        transition: all 0.5s cubic-bezier(.55,-0.68,.48,1.682);
    }

    #taskbar button.active {
        background: @wb-act-bg;
        color: @wb-act-color;
        margin-left: ${toString margin}px;
        padding-left: ${toString padActive}px;
        padding-right: ${toString padActive}px;
        margin-right: ${toString margin}px;
        animation: gradient_f 20s ease-in infinite;
        transition: all 0.3s cubic-bezier(.55,-0.68,.48,1.682);
    }

    #taskbar button:hover {
        background: @wb-hvr-bg;
        color: @wb-hvr-color;
        padding-left: ${toString padS}px;
        padding-right: ${toString padS}px;
        animation: gradient_f 20s ease-in infinite;
        transition: all 0.3s cubic-bezier(.55,-0.68,.48,1.682);
    }

    #cpu,
    #memory,
    #battery,
    #wireplumber,
    #disk,
    #clock,
    #workspaces,
    #window,
    #taskbar,
    #network,
    #bluetooth,
    #pulseaudio,
    #mpris,
    #backlight,
    #custom-updates,
    #custom-wallchange,
    #custom-mode,
    #custom-cliphist,
    #custom-power,
    #custom-wbar,
    #custom-l_end,
    #custom-r_end,
    #custom-sl_end,
    #custom-sr_end,
    #custom-rl_end,
    #custom-rr_end,
    #custom-weather,
    #custom-events,
    #tray {
        color: @main-color;
        background: @main-bg;
        opacity: 1;
        margin: ${toString modVMargin}px 0px ${toString modVMargin}px 0px;
        padding-left: ${toString padM}px;
        padding-right: ${toString padM}px;
    }

    #workspaces,
    #taskbar {
        padding: 0px;
    }

    #custom-r_end {
        border-radius: 0px ${toString rLarge}px ${toString rLarge}px 0px;
        margin-right: ${toString margin}px;
        padding-right: ${toString padS}px;
    }

    #custom-l_end {
        border-radius: ${toString rLarge}px 0px 0px ${toString rLarge}px;
        margin-left: ${toString margin}px;
        padding-left: ${toString padS}px;
    }

    #custom-sr_end {
        border-radius: 0px;
        margin-right: ${toString margin}px;
        padding-right: ${toString padS}px;
    }

    #custom-sl_end {
        border-radius: 0px;
        margin-left: ${toString margin}px;
        padding-left: ${toString padS}px;
    }

    #custom-rr_end {
        border-radius: 0px ${toString rTiny}px ${toString rTiny}px 0px;
        margin-right: ${toString margin}px;
        padding-right: ${toString padS}px;
    }

    #custom-rl_end {
        border-radius: ${toString rTiny}px 0px 0px ${toString rTiny}px;
        margin-left: ${toString margin}px;
        padding-left: ${toString padS}px;
    }
  ''
