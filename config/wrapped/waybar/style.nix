{
  pkgs,
  config,
  ...
}:
let
  size = if config.networking.hostName == "yaldabaoth" then 8 else 10;
in
pkgs.writeText "style.css" ''
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
  @define-color tool-color #cdd6f4;
  @define-color tool-border #000000;

  @define-color wb-color #cdd6f4;

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
      border-radius: 21px;
      border-width: 1px;
      border-style: solid;
      border-color: @tool-border;
  }

  #workspaces button {
      box-shadow: none;
  	  text-shadow: none;
      padding: 0px;
      border-radius: 16px;
      margin-top: 3px;
      margin-bottom: 3px;
      padding-left: 3px;
      padding-right: 3px;
      color: @wb-color;
      animation: gradient_f 20s ease-in infinite;
      transition: all 0.5s cubic-bezier(.55,-0.68,.48,1.682);
  }

  #workspaces button.active {
      background: @wb-act-bg;
      color: @wb-act-color;
      margin-left: 3px;
      padding-left: ${toString size}px;
      padding-right: ${toString size}px;
      margin-right: 3px;
      animation: gradient_f 20s ease-in infinite;
      transition: all 0.3s cubic-bezier(.55,-0.68,.48,1.682);
  }

  #workspaces button:hover {
      background: @wb-hvr-bg;
      color: @wb-hvr-color;
      padding-left: 3px;
      padding-right: 3px;
      animation: gradient_f 20s ease-in infinite;
      transition: all 0.3s cubic-bezier(.55,-0.68,.48,1.682);
  }

  #taskbar button {
      box-shadow: none;
  	text-shadow: none;
      padding: 0px;
      border-radius: 9px;
      margin-top: 3px;
      margin-bottom: 3px;
      padding-left: 3px;
      padding-right: 3px;
      color: @wb-color;
      animation: gradient_f 20s ease-in infinite;
      transition: all 0.5s cubic-bezier(.55,-0.68,.48,1.682);
  }

  #taskbar button.active {
      background: @wb-act-bg;
      color: @wb-act-color;
      margin-left: 3px;
      padding-left: 12px;
      padding-right: 12px;
      margin-right: 3px;
      animation: gradient_f 20s ease-in infinite;
      transition: all 0.3s cubic-bezier(.55,-0.68,.48,1.682);
  }

  #taskbar button:hover {
      background: @wb-hvr-bg;
      color: @wb-hvr-color;
      padding-left: 3px;
      padding-right: 3px;
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
      margin: 4px 0px 4px 0px;
      padding-left: 4px;
      padding-right: 4px;
  }

  #workspaces,
  #taskbar {
      padding: 0px;
  }

  #custom-r_end {
      border-radius: 0px 21px 21px 0px;
      margin-right: 9px;
      padding-right: 3px;
  }

  #custom-l_end {
      border-radius: 21px 0px 0px 21px;
      margin-left: 9px;
      padding-left: 3px;
  }

  #custom-sr_end {
      border-radius: 0px;
      margin-right: 9px;
      padding-right: 3px;
  }

  #custom-sl_end {
      border-radius: 0px;
      margin-left: 9px;
      padding-left: 3px;
  }

  #custom-rr_end {
      border-radius: 0px 7px 7px 0px;
      margin-right: 9px;
      padding-right: 3px;
  }

  #custom-rl_end {
      border-radius: 7px 0px 0px 7px;
      margin-left: 9px;
      padding-left: 3px;
  }
''
