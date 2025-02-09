{pkgs, ...}: {
  home.packages = with pkgs; [
    zed-editor
  ];
  xdg.configFile."zed/settings.json".text = builtins.toJSON {
    buffer_font_family = "JetBrainsMono Nerd Font";
    buffer_font_features = {
      calt = true;
      clig = true;
      cv02 = true;
      cv03 = true;
      cv04 = true;
      cv05 = true;
      cv06 = true;
      cv07 = true;
      cv11 = true;
      cv14 = true;
      cv15 = true;
      cv16 = true;
      cv17 = true;
      liga = true;
      ss20 = true;
    };
    buffer_font_size = 12;
    buffer_font_weight = 200;
    telemetry = {
      diagnostics = false;
      metrics = false;
    };
    theme = {
      dark = "One Dark";
      light = "Andromeda";
      mode = "system";
    };
    ui_font_size = 12;
    vim_mode = true;
  };
}
