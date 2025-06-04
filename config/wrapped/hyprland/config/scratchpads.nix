{
  mod ? "Super",
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    getExe
    fold
    ;

  inherit (pkgs) writeShellScriptBin;
  scratchpads = [
    {
      name = "signal";
      prefix = "s";
      cmd = "${getExe pkgs.signal-desktop} --enable-features=UseOzonePlatform --ozone-platform=wayland";
    }
    rec {
      name = "ghostty.term";
      prefix = "t";
      cmd = "ghostty --class=${name}";
    }
    rec {
      name = "ghostty.notes";
      prefix = "n";
      cmd = "ghostty --class=${name} -e 'tmux new-session -As Notes -c ~/Documents/Notes/Contents/ \'direnv exec . nvim\''";
    }
    rec {
      name = "ghostty.music";
      prefix = "m";
      cmd = "ghostty --class=${name} -e spotify_player";
    }

    rec {
      name = "ghostty.btop";
      prefix = "b";
      cmd = "ghostty --class=${name} -e ${getExe pkgs.configured.btop}";
    }
  ];

  mkCondition =
    curr: acc:
    let
      ifStatement = if acc == '''' then "if" else "elif";
    in
    # sh
    ''
      ${acc}
      ${ifStatement} [ "''$1" = "${curr.name}" ]; then
        toggle_scratchpad ''$1 "${curr.cmd}"
    '';

  conditional =
    # sh
    ''
      ${fold mkCondition '''' scratchpads}
      fi
    '';

  script =
    writeShellScriptBin "scratchpad"
      # sh
      ''
        windows_in(){
        hyprctl clients -j | ${getExe pkgs.jq} ".[] | select(.workspace.name == \"special:''$1\" )"
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
in
map (
  scratchpad: "${mod}, ${scratchpad.prefix}, exec, ${getExe script} ${scratchpad.name}"
) scratchpads
