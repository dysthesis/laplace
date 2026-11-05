{
  pkgs,
  lib,
  config,
  terminal,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
  fontSize = config.laplace.display.fuzzel.fontSize;
  # Fuzzel parses desktop-entry syntax, not shell-escaped argument vectors.
  terminalCommand = pkgs.writeShellScript "fuzzel-terminal" ''
    exec ${lib.escapeShellArgs terminal.launch} "$@"
  '';
  configFile =
    {
      main = {
        terminal = "${terminalCommand}";
        font = "IosevkaCadmus Nerd Font:size=${toString fontSize}";
        prompt = " ";
        layer = "overlay";
        lines = 12;
        width = 80;
        "horizontal-pad" = 10;
        "vertical-pad" = 8;
        "inner-pad" = 8;
      };

      colors = {
        background = "000000ee";
        text = "ffffffff";
        match = "7788aaff";
        selection = "080808ff";
        "selection-text" = "ffffffff";
        "selection-match" = "ffcc66ff";
        border = "ffffffff";
      };

      border = {
        width = 1;
        radius = 8;
      };
    }
    |> lib.generators.toINI {}
    |> pkgs.writeText "fuzzel.ini";
in
  mkWrapper pkgs pkgs.fuzzel {addFlags = ["--config=${configFile}"];}
