{
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mapAttrsToList mapAttrs getExe;
  mod = "Super";
  modShift = "${mod} SHIFT";
  numWorkspaces = 10;
  audioIncreaseDelta = toString 5;
  brightnessIncreaseDelta = toString 5;
  # From fufexan
  # binds $mod + [shift +] {1..10} to [move to] workspace {1..10}
  workspaces = builtins.concatLists (builtins.genList (
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
    numWorkspaces);

  exec = pkg: "exec, ${getExe pkg}";
  mkKeys = modKey: mapAttrsToList (key: val: "${modKey}, ${key}, ${val}");
in {
  bind =
    mkKeys mod ({
        "Q" = "killactive";
        "F" = "fullscreen";
        "Return" = exec pkgs.configured.ghostty;
        "S" = ''exec, '${getExe pkgs.slurp} | ${getExe pkgs.grim} -g - - | ${pkgs.wl-clipboard}/bin/wl-copy' '';
        "R" = "exec, ${pkgs.configured.bemenu}/bin/bemenu-run";
      }
      // mapAttrs (_key: value: "movefocus, ${value}") {
        "H" = "l";
        "J" = "d";
        "K" = "u";
        "L" = "r";
      })
    ++ (mkKeys modShift {
      "F" = "togglefloating";
      "L" = exec pkgs.hyprlock;
    })
    ++ workspaces
    ++ (import ./scratchpads.nix {inherit pkgs lib mod;});

  bindle = mapAttrsToList (key: value: ", ${key}, exec, ${value}") {
    "XF86AudioRaiseVolume" = "wpctl set-volume @DEFAULT_AUDIO_SINK@ ${audioIncreaseDelta}%+";
    "XF86AudioLowerVolume" = "wpctl set-volume @DEFAULT_AUDIO_SINK@ ${audioIncreaseDelta}%-";

    # backlight
    "XF86MonBrightnessUp" = "brightnessctl set ${brightnessIncreaseDelta}%+";
    "XF86MonBrightnessDown" = "brightnessctl set ${brightnessIncreaseDelta}%-";
  };
}
