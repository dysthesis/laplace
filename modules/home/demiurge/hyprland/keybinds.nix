{
  pkgs,
  lib,
  ...
}: {
  wayland.windowManager.hyprland.settings = {
    bind =
      [
        "$mod, Return, exec, wezterm"
        "$mod, Q, killactive"
        "$mod, R, exec, anyrun"
        ''$mod, P, exec, ${lib.getExe pkgs.grim} -g "$(${lib.getExe pkgs.slurp})" - | ${lib.getExe pkgs.swappy} -f -''
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
        "$mod, F, fullscreen"
        "$mod, Tab, changegroupactive, f"
        "$mod+Shift, Tab, changegroupactive, b"
        "$mod, T, togglegroup"
        "$mod+Shift, W, moveintogroup, u"
        "$mod+Shift, A, moveintogroup, l"
        "$mod+Shift, S, moveintogroup, d"
        "$mod+Shift, D, moveintogroup, r"
        "$mod+Shift, E, moveoutofgroup"
        "$mod+Shift, L, exec, swaylock"
        "$mod, Backspace, exec, wlogout -p layer-shell"
        "$mod+Shift, F, exec, firefox"
        "$mod, N, exec, neovide"
        "$mod, x, exec, firefox"
        "$mod, E, exec, emacsclient -c -a 'emacs'"
        "$mod, Z, exec, pypr toggle term"
        "$mod, B, exec, pypr toggle btop"
        "$mod, S, exec, pypr toggle signal"
        "$mod, M, exec, pypr toggle music"
        "$mod, I, exec, pypr toggle irc"
        "$mod, C, exec, pypr toggle khal"
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
