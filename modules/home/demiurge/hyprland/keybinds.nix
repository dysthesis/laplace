{
  inputs,
  pkgs,
  lib,
  ...
}: let
  inherit (pkgs) writeShellScriptBin;
  inherit (lib) getExe;
  powermenu =
    writeShellScriptBin "powermenu"
    /*
    sh
    */
    ''
      case "$(printf "Shutdown\nRestart\nLock" | bemenu -p "" \
          -l 3)" in
      Shutdown)
          exec systemctl poweroff
          ;;
      Restart)
          exec systemctl reboot
          ;;
      Lock)
          exec hyprlock
          ;;
      esac
    '';
  passmenu =
    writeShellScriptBin "passmenu"
    /*
    sh
    */
    ''
      shopt -s nullglob globstar

      typeit=0
      if [[ $1 == "--type" ]]; then
       typeit=1
       shift
      fi
      prefix=''${PASSWORD_STORE_DIR-$XDG_DATA_HOME/password-store}
      password_files=( "$prefix"/**/*.gpg )
      password_files=( "''${password_files[@]#"$prefix"/}" )
      password_files=( "''${password_files[@]%.gpg}" )

      password=$(printf '%s\n' "''${password_files[@]}" | bemenu -b --fn "JBMono Nerd Font 10" --fb "#000000" --ff "#ffffff" --nb "#000000" --nf "#ffffff" --tb "#89b4fa" --hb "#000000" --tf "#000000" --hf "#89b4fa" --ab "#000000" -p "󰟵" -H 34 --hp 8 "$@")

      [[ -n $password ]] || exit

      if [[ $typeit -eq 0 ]]; then
       PASSWORD_STORE_DIR="$XDG_DATA_HOME/password-store" pass show -c "$password" 2>/dev/null
      else
       PASSWORD_STORE_DIR="$XDG_DATA_HOME/password-store" pass show "$password" | { IFS= read -r pass; printf %s "$pass"; } | $xdotool
      fi
    '';
in {
  home.packages = with inputs.babel.packages.${pkgs.system}; [jbcustom-nf];
  wayland.windowManager.hyprland.settings = {
    "$mod" = "SUPER";
    bind = with pkgs;
      [
        "$mod, Return, exec, ghostty"
        "$mod, Q, killactive"
        "$mod, R, exec, bemenu-run"
        ''$mod, P, exec, ${getExe grim} -g "$(${getExe slurp})" - | ${getExe swappy} -f -''
        "$mod+Shift, P, exec, ${getExe passmenu}"
        "$mod+Shift, Escape, exec, ${getExe powermenu}"
        "$mod, H, movefocus, l"
        "$mod, L, movefocus, r"
        "$mod, J, movefocus, d"
        "$mod, K, movefocus, u"
        "$mod+Shift, H, movewindow, l"
        "$mod+Shift, L, movewindow, r"
        "$mod+Shift, J, movewindow, d"
        "$mod+Shift, K, movewindow, u"
        "$mod+Shift, Tab,  focusmonitor, +1"
        "$mod,  Semicolon, splitratio, -0.1"
        "$mod, Apostrophe, splitratio, 0.1"
        "$mod+Shift, F, fullscreen"
        "$mod, Tab, changegroupactive, f"
        "$mod+Shift, Tab, changegroupactive, b"
        "$mod+Shift, T, togglegroup"
        "$mod+Shift, W, moveintogroup, u"
        "$mod+Shift, A, moveintogroup, l"
        "$mod+Shift, S, moveintogroup, d"
        "$mod+Shift, D, moveintogroup, r"
        "$mod+Shift, E, moveoutofgroup"
      ]
      ++ (
        # workspaces
        # binds $mod + [shift +] {1..10} to [move to] workspace {1..10}
        builtins.concatLists (builtins.genList (
            x: let
              ws = let
                c = (x + 1) / 10;
              in
                builtins.toString (x + 1 - (c * 10));
            in [
              "$mod, ${ws}, focusworkspaceoncurrentmonitor, ${toString (x + 1)}"
              "$mod SHIFT, ${ws}, movetoworkspace, ${toString (x + 1)}"
            ]
          )
          10)
      );

    bindm = [
      "$mod, mouse:272, movewindow"
      "$mod, mouse:273, resizewindow"
    ];

    bindle = [
      ", XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
      ", XF86AudioLowerVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%-"
      ", XF86MonBrightnessUp, exec, ${getExe pkgs.brightnessctl} set 5%+"
      ", XF86MonBrightnessDown, exec, ${getExe pkgs.brightnessctl} set 5%-"
    ];
  };
}
