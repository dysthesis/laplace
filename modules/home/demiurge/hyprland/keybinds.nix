{
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
in {
  wayland.windowManager.hyprland.settings = {
    "$mod" = "SUPER";
    bind =
      [
        "$mod, Return, exec, wezterm start --always-new-process"
        "$mod, Q, killactive"
        "$mod, R, exec, bemenu-run"
        ''$mod, P, exec, ${getExe pkgs.grim} -g "$(${getExe pkgs.slurp})" - | ${getExe pkgs.swappy} -f -''
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
    ];
  };
}
