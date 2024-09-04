{
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    getExe
    fold
    ;
  inherit (pkgs) writeShellScriptBin;
  wezterm = getExe pkgs.wezterm;
  scratchpads = [
    {
      name = "signal";
      prefix = "s";
      cmd = "${getExe pkgs.signal-desktop} --enable-features=UseOzonePlatform --ozone-platform=wayland";
    }
    {
      name = "term";
      prefix = "t";
      cmd = "${wezterm}";
    }
    {
      name = "notes";
      prefix = "n";
      cmd = "${wezterm} start sh -c '${getExe pkgs.tmux} new-session -A -s Notes -c ~/Documents/Notes/'";
    }
    {
      name = "fm";
      prefix = "f";
      cmd = "${wezterm} start ${getExe pkgs.yazi}";
    }
    {
      name = "btop";
      prefix = "b";
      cmd = "${wezterm} start ${getExe pkgs.btop}";
    }
  ];

  mkCondition = curr: acc: let
    ifStatement =
      if acc == ''''
      then "if"
      else "elif";
  in
    /*
    sh
    */
    ''
      ${acc}
      ${ifStatement} [ "''$1" = "${curr.name}" ]; then
        toggle_scratchpad ''$1 "${curr.cmd}"
    '';

  conditional =
    /*
    sh
    */
    ''
      ${fold mkCondition '''' scratchpads}
      fi
    '';

  script =
    writeShellScriptBin "scratchpad"
    /*
    sh
    */
    ''
      windows_in(){
      hyprctl clients -j | jq ".[] | select(.workspace.name == \"special:''$1\" )"
      }

      toggle_scratchpad(){
          workspace_name="''$1"
          cmd="''$2"

          windows=''$( windows_in "''$workspace_name" )
          # If not on latest , check the edit history of this post
          if [ -z "''$windows" ];then
              hyprctl dispatch "exec [workspace special:''$workspace_name] ''$cmd"
              else
              hyprctl dispatch togglespecialworkspace "''$workspace_name"
          fi
      }

      ${conditional}
    '';
in {
  wayland.windowManager.hyprland.settings.bind =
    map
    (scratchpad: "$mod, ${scratchpad.prefix}, exec, ${script} ${scratchpad.name}")
    scratchpads;
}
