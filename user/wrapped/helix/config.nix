{ pkgs, ... }:
let
  tomlFormat = pkgs.formats.toml { };
  config = {
    theme = "demiurge";
    editor = {
      completion-trigger-len = 1;
      default-yank-register = "+";
      line-number = "relative";
      mouse = false;
      cursor-shape = {
        insert = "bar";
        normal = "block";
        select = "underline";
      };
      file-picker.hidden = false;
      statusline = {
        left = [
          "mode"
          "spinner"
          "file-name"
          "file-type"
          "total-line-numbers"
          "file-encoding"
        ];
        center = [ ];
        right = [
          "selections"
          "primary-selection-length"
          "position"
          "position-percentage"
          "spacer"
          "diagnostics"
          "workspace-diagnostics"
          "version-control"
        ];
      };
    };
    keys = {
      normal = {
        "#" = "toggle_comments";
        "^" = "goto_first_nonwhitespace";
        "$" = "goto_line_end";
        "K" = "hover";
        "A-k" = "keep_selections";
        space = { "l" = ":reflow"; };
      };
      select = {
        "^" = "goto_first_nonwhitespace";
        "$" = "goto_line_end";
        "g" = { "e" = "goto_file_end"; };
      };
    };
  };
in tomlFormat.generate "helix-config" config
