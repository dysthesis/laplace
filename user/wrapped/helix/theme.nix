{ pkgs, ... }:
let
  tomlFormat = pkgs.formats.toml { };
  # Customised lackluster theme
  config = {
    comment = "comment";
    constant = "gray7";
    "constant.builtin" = "gray6";
    diagnostic = {
      fg = "gray4";
    };
    "diagnostic.deprecated" = {
      fg = "gray4";
      modifiers = [ "crossed_out" ];
    };
    "diagnostic.error" = {
      fg = "gray4";
      underline = {
        color = "gray4";
        style = "curl";
      };
    };
    "diagnostic.unnecessary" = {
      fg = "gray4";
      modifiers = [ "dim" ];
    };
    "diagnostic.warning" = {
      fg = "gray4";
      underline = {
        color = "gray4";
        style = "curl";
      };
    };
    diff = {
      fg = "gray3";
    };
    "diff.delta" = {
      fg = "blue";
    };
    "diff.delta.conflict" = {
      fg = "yellow";
    };
    "diff.delta.gutter" = {
      fg = "gray4";
      modifiers = [ "dim" ];
    };
    "diff.minus" = {
      fg = "red";
    };
    "diff.minus.gutter" = {
      fg = "red";
      modifiers = [ "dim" ];
    };
    "diff.plus" = {
      fg = "green";
    };
    "diff.plus.gutter" = {
      fg = "gray4";
    };
    error = {
      fg = "red";
    };
    function = {
      fg = "gray6b";
    };
    "function.builtin" = {
      fg = "gray5";
      modifiers = [ "bold" ];
    };
    "function.method" = {
      fg = "gray6";
    };
    hint = "gray4";
    info = "gray4";
    keyword = "special_keyword";
    "keyword.control.exception" = "blue";
    "keyword.control.return" = "green";
    "keyword.operator" = "punctuation";
    "markup.bold" = {
      modifiers = [ "bold" ];
    };
    "markup.heading" = {
      fg = "gray5";
    };
    "markup.heading.1" = {
      fg = "gray6";
    };
    "markup.italic" = {
      modifiers = [ "italic" ];
    };
    "markup.link" = "blue";
    "markup.link.url" = {
      fg = "green";
    };
    "markup.list" = {
      fg = "gray4";
    };
    "markup.quote" = {
      fg = "gray5";
    };
    "markup.raw" = {
      fg = "lack";
    };
    "markup.raw.block" = {
      fg = "lack";
      modifiers = [ "bold" ];
    };
    "markup.strikethrough" = {
      modifiers = [ "crossed_out" ];
    };
    operator = "gray6";
    palette = {
      black = "#000000";
      blue = "#7788aa";
      comment = "#3a3a3a";
      exception = "#505050";
      gray1 = "#080808";
      gray2 = "#191919";
      gray3 = "#2a2a2a";
      gray4 = "#444444";
      gray5 = "#555555";
      gray6 = "#7a7a7a";
      gray6b = "#909090";
      gray7 = "#aaaaaa";
      gray8 = "#cccccc";
      gray9 = "#dddddd";
      green = "#789978";
      lack = "#708090";
      luster = "#deeeed";
      main_background = "#101010";
      menu_background = "#191919";
      orange = "#ffaa88";
      param = "#8e8e8e";
      popup_background = "#1a1a1a";
      red = "#d70000";
      special_keyword = "#666666";
      statusline = "#242424";
      whitespace = "#202020";
      yellow = "#abab77";
    };
    punctuation = "gray6";
    special = "blue";
    string = "green";
    "string.special" = "green";
    tabstop = "gray4";
    tag = {
      fg = "gray5";
    };
    type = {
      fg = "gray7";
    };
    "type.enum" = "special_keyword";
    "ui.background" = {
      bg = "background";
      fg = "#ffffff";
    };
    "ui.background.separator" = {
      bg = "main_background";
      fg = "gray5";
    };
    "ui.cursor" = {
      bg = "gray6";
      fg = "black";
    };
    "ui.cursor.insert" = {
      bg = "gray4";
      fg = "gray8";
    };
    "ui.cursor.match" = {
      bg = "gray3";
      fg = "gray7";
    };
    "ui.cursor.normal" = {
      bg = "gray6";
      fg = "black";
    };
    "ui.cursor.primary" = {
      bg = "gray8";
      fg = "black";
    };
    "ui.cursor.primary.insert" = {
      bg = "gray5";
      fg = "gray8";
    };
    "ui.cursor.primary.normal" = {
      bg = "gray8";
      fg = "black";
    };
    "ui.cursor.primary.select" = {
      bg = "gray8";
      fg = "black";
    };
    "ui.cursor.select" = {
      bg = "gray6";
      fg = "black";
    };
    "ui.cursorcolumn.primary" = {
      bg = "#171717";
    };
    "ui.cursorcolumn.secondary" = {
      bg = "#171717";
    };
    "ui.cursorline.primary" = {
      bg = "#171717";
    };
    "ui.cursorline.secondary" = {
      bg = "#171717";
    };
    "ui.debug.active" = {
      fg = "green";
    };
    "ui.debug.breakpoint" = {
      fg = "blue";
    };
    "ui.help" = {
      bg = "popup_background";
      fg = "gray6";
    };
    "ui.highlight" = {
      bg = "gray3";
    };
    "ui.linenr" = "gray4";
    "ui.linenr.selected" = "gray7";
    "ui.menu" = {
      bg = "popup_background";
      fg = "gray6";
    };
    "ui.menu.scroll" = {
      bg = "gray3";
      fg = "gray4";
    };
    "ui.menu.selected" = {
      bg = "gray8";
      fg = "black";
    };
    "ui.picker.header" = {
      fg = "gray4";
    };
    "ui.popup" = {
      bg = "popup_background";
      fg = "gray6";
    };
    "ui.selection" = {
      bg = "#252525";
    };
    "ui.selection.primary" = {
      bg = "#252525";
    };
    "ui.statusline" = {
      bg = "statusline";
      fg = "gray7";
    };
    "ui.statusline.inactive" = {
      bg = "gray1";
      fg = "gray4";
    };
    "ui.statusline.insert" = {
      bg = "lack";
      fg = "gray9";
    };
    "ui.statusline.select" = {
      bg = "gray9";
      fg = "black";
    };
    "ui.text" = {
      fg = "gray8";
    };
    "ui.text.directory" = {
      fg = "gray6";
    };
    "ui.text.focus" = {
      bg = "gray3";
    };
    "ui.text.info" = {
      fg = "gray8";
    };
    "ui.virtual.inlay-hint" = "gray4";
    "ui.virtual.inlay-hint.parameter" = "orange";
    "ui.virtual.inlay-hint.type" = "gray4";
    "ui.virtual.jump-label" = {
      fg = "blue";
    };
    "ui.virtual.ruler" = {
      bg = "#171717";
    };
    "ui.virtual.wrap" = {
      fg = "gray4";
    };
    "ui.window" = {
      fg = "gray6";
    };
    variable = {
      fg = "gray8";
    };
    "variable.other.memeber" = {
      fg = "gray7";
    };
    "variable.parameter" = "param";
    warning = "orange";
  };
in
tomlFormat.generate "demiurge.toml" config
