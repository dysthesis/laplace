{pkgs, ...}: {
  home.packages = with pkgs; [
    jq
  ];
  programs.hyprlock = {
    enable = true;
    settings = {
      extraConfig = let
        weather = pkgs.stdenv.mkDerivation {
          name = "weather";
          buildInputs = [
            (pkgs.python311.withPackages
              (ps: with ps; [requests]))
          ];
          unpackPhase = "true";
          installPhase = ''
            mkdir -p $out/bin
            cp ${./weather.py} $out/bin/weather
            chmod +x $out/bin/weather
          '';
        };
      in ''
        general {
          no_fade_in = false
          grace = 0
          disable_loading_bar = false
          hide_cursor = true
          ignore_empty_input = true
          #text_trim = true
        }

        #BACKGROUND
        background {
            monitor =
            path = ${../wallpaper.png}
            blur_size = 2
            blur_passes = 3 # 0 disables blurring
            contrast = 1.3000
            brightness = 0.8000
            vibrancy = 0.2100
            vibrancy_darkness = 0.0
        }

        # TIME HR
        label {
            monitor =
            text = cmd[update:1000] date +"%H"
            color = rgba(255, 255, 255, 1)
            #shadow_pass = 2
            shadow_size = 3
            shadow_color = rgb(0,0,0)
            shadow_boost = 1.2
            font_size = 150
            font_family = JetBrainsMono Nerd Font Black
            position = 0, -100
            halign = center
            valign = top
        }

        # TIME
        label {
            monitor =
            text = cmd[update:1000] date +"%M"
            color = rgba(255, 255, 255, 1)
            font_size = 150
            font_family = JetBrainsMono Nerd Font Regular
            position = 0, -270
            halign = center
            valign = top
        }

        # DATE
        label {
            monitor =
            text = cmd[update:1000] date +"%d %b %A"
            color = rgba(255, 255, 255, 1)
            font_size = 14
            font_family = SF Pro Display Regular
            position = 0, 0
            halign = center
            valign = center
        }

        # LOCATION & WEATHER
        label {
            monitor =
            text = cmd[update:600] python3 ${weather}/bin/weather hyprlock IDN10064 | jq -r '.text'
            color = rgba(255, 255, 255, 1)
            font_size = 14
            font_family = SF Pro Display Black
            position = 0, 465
            halign = center
            valign = center
        }


        # Music
        image {
            monitor =
            path =
            size = 60 # lesser side if not 1:1 ratio
            rounding = 5 # negative values mean circle
            border_size = 0
            rotate = 0 # degrees, counter-clockwise
            reload_time = 2
            reload_cmd = ~/.scripts/playerctlock.sh --arturl
            position = -130, -309
            halign = center
            valign = center
            #opacity=0.5
        }

        # INPUT FIELD
        input-field {
            monitor =
            size = 250, 60
            outline_thickness = 3
            outer_color = rgba(0, 0, 0, 1)
            dots_size = 0.1 # Scale of input-field height, 0.2 - 0.8
            dots_spacing = 1 # Scale of dots' absolute size, 0.0 - 1.0
            dots_center = true
            inner_color = rgba(0, 0, 0, 1)
            font_color = rgba(200, 200, 200, 1)
            fade_on_empty = false
            #font_family = JetBrains Mono Nerd Font Mono
            placeholder_text = <span foreground="##cdd6f4">   $USER</span>
            hide_input = false
            position = 0, -470
            halign = center
            valign = center
            zindex = 10
        }
        # Information
        #label {
           # monitor =
            #text = cmd[update:1000] echo -e "$(~/.config/hypr/bin/infonlock.sh)"
            #color = rgba(255, 255, 255, 1)
            #font_size = 12
            #font_family = JetBrains Mono Nerd Font Mono ExtraBold
            #position = -20, -510
            #halign = right
            #valign = center
        #}
      '';
    };
  };
}
