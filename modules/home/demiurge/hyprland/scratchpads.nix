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
  taskwarrior-0_25_4 = pkgs.rust.packages.stable.rustPlatform.buildRustPackage rec {
    pname = "taskwarrior-tui";
    version = "0.25.4";

    src = pkgs.fetchFromGitHub {
      owner = "kdheepak";
      repo = "taskwarrior-tui";
      rev = "v${version}";
      sha256 = "sha256-M8tiEUPfP5EWfPp7i6r0lpHC5ZUsEYeEKVz5gUpe4+A=";
    };

    cargoHash = "sha256-B5peoyT/+miHXyoRGFLUv9qFzZZFsExrI46Zy0K7NL4=";

    nativeBuildInputs = [pkgs.installShellFiles];

    # Because there's a test that requires terminal access
    doCheck = false;

    postInstall = ''
      installManPage docs/taskwarrior-tui.1
      installShellCompletion completions/taskwarrior-tui.{bash,fish} --zsh completions/_taskwarrior-tui
    '';

    meta = with lib; {
      description = "A terminal user interface for taskwarrior ";
      homepage = "https://github.com/kdheepak/taskwarrior-tui";
      license = with licenses; [mit];
      maintainers = with maintainers; [matthiasbeyer];
      mainProgram = "taskwarrior-tui";
    };
  };

  inherit (pkgs) writeShellScriptBin;
  scratchpads = [
    {
      name = "signal";
      prefix = "s";
      cmd = "${getExe pkgs.signal-desktop} --enable-features=UseOzonePlatform --ozone-platform=wayland";
    }
    rec {
      name = "term";
      prefix = "t";
      cmd = "wezterm start --class=${name}";
    }
    rec {
      name = "notes";
      prefix = "n";
      cmd = "wezterm start --class=${name} -- sh -c 'tmux new-session -A -s Notes -c ~/Documents/Notes/'";
    }
    rec {
      name = "fm";
      prefix = "f";
      cmd = "wezterm start --class=${name} -- yazi";
    }
    rec {
      name = "btop";
      prefix = "b";
      cmd = "wezterm start --class=${name} -- btop";
    }
    rec {
      name = "task";
      prefix = "d";
      cmd = "wezterm start --class=${name} -- ${getExe taskwarrior-0_25_4}";
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
in {
  wayland.windowManager.hyprland.settings.bind =
    map
    (scratchpad: "$mod, ${scratchpad.prefix}, exec, ${getExe script} ${scratchpad.name}")
    scratchpads;
}
