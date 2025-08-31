{
  hyprlock ? pkgs.hyprlock,
  hyprland ? pkgs.hyprland,
  pkgs,
  lib,
  inputs,
  ...
}: let
  inherit (lib) mapAttrsToList mapAttrs getExe;

  emacs = inputs.jormungandr.packages.${pkgs.system}.default;
  mod = "Super";
  modShift = "${mod} SHIFT";
  numWorkspaces = 10;
  audioIncreaseDelta = toString 5;
  brightnessIncreaseDelta = toString 5;
  # From fufexan
  # binds $mod + [shift +] {1..10} to [move to] workspace {1..10}
  workspaces = builtins.concatLists (
    builtins.genList (
      x: let
        ws = let
          c = (x + 1) / 10;
        in
          builtins.toString (x + 1 - (c * 10));
      in [
        "${mod}, ${ws}, focusworkspaceoncurrentmonitor, ${toString (x + 1)}"
        "${mod} SHIFT, ${ws}, movetoworkspace, ${toString (x + 1)}"
      ]
    )
    numWorkspaces
  );

  exec = pkg: "exec, ${getExe pkg}";
  mkKeys = modKey: mapAttrsToList (key: val: "${modKey}, ${key}, ${val}");
in {
  bind =
    mkKeys mod (
      {
        "Q" = "killactive";
        "F" = "fullscreen";
        "Return" = exec pkgs.configured.ghostty;
        "R" = "exec, ${pkgs.configured.bemenu}/bin/bemenu-run";
        "E" = "exec, ${emacs}/bin/emacsclient -c";
        "G" = "togglegroup,";
        "W" = "moveintogroup, u";
        "A" = "moveintogroup, l";
        "S" = "moveintogroup, d";
        "D" = "moveintogroup, r";
        "Tab" = "changegroupactive, f";
        "Alt" = ", ,resizeactive,";
      }
      // mapAttrs (_key: value: "movefocus, ${value}") {
        "H" = "l";
        "J" = "d";
        "K" = "u";
        "L" = "r";
      }
    )
    ++ (mkKeys modShift {
      "W" = "moveoutofgroup, up";
      "A" = "moveoutofgroup, left";
      "S" = "moveoutofgroup, down";
      "D" = "moveoutofgroup, right";
      "F" = "togglefloating";
      "L" = exec hyprlock;
      "P" = "${lib.getExe pkgs.grimblast} --notify copy area";
      "Tab" = "changegroupactive, b";
    })
    ++ workspaces
    ++ (import ./scratchpads.nix {
      inherit
        pkgs
        lib
        mod
        hyprland
        ;
    });

  binde = mkKeys mod {
    "right" = "resizeactive, 10 0";
    "left" = "resizeactive, -10 0";
    "up" = "resizeactive, 0, -10";
    "down" = "resizeactive, 0, 10";
  };

  bindle = mapAttrsToList (key: value: ", ${key}, exec, ${value}") {
    "XF86AudioRaiseVolume" = "wpctl set-volume @DEFAULT_AUDIO_SINK@ ${audioIncreaseDelta}%+";
    "XF86AudioLowerVolume" = "wpctl set-volume @DEFAULT_AUDIO_SINK@ ${audioIncreaseDelta}%-";

    # backlight
    "XF86MonBrightnessUp" = "brightnessctl set ${brightnessIncreaseDelta}%+";
    "XF86MonBrightnessDown" = "brightnessctl set ${brightnessIncreaseDelta}%-";
  };
}
