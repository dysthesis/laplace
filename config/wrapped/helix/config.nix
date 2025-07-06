{pkgs, ...}: let
  tomlFormat = pkgs.formats.toml {};
  config = {
    theme = "kanagawa-dragon";
    editor = {
      line-number = "relative";
      mouse = false;
      cursor-shape = {
        insert = "bar";
        normal = "block";
        select = "underline";
      };
      file-picker.hidden = false;
    };
  };
in
  tomlFormat.generate "helix-config" config
