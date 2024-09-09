{systemConfig, ...}: {
  programs.zathura = {
    enable = true;
    options = {
      font = let
        size =
          if systemConfig.networking.hostName == "yaldabaoth"
          then 6
          else 8;
      in "JetBrainsMono Nerd Font ${toString size}";
      sandbox = "strict";
      smooth-scroll = true;
      guioptions = "sv";
      statusbar-h-padding = 10;
      statusbar-v-padding = 10;
      scroll-page-aware = "true";
      selection-clipboard = "clipboard";
      default-fg = "#FFFFFF";
      default-bg = "rgba(0,0,0,0.4)";

      completion-bg = "#11111B";
      completion-fg = "#FFFFFF";
      completion-highlight-bg = "#575268";
      completion-highlight-fg = "#FFFFFF";
      completion-group-bg = "#11111B";
      completion-group-fg = "#89B4FA";

      statusbar-fg = "#FFFFFF";
      statusbar-bg = "#11111B";

      notification-bg = "#11111B";
      notification-fg = "#FFFFFF";
      notification-error-bg = "#11111B";
      notification-error-fg = "#F38BA8";
      notification-warning-bg = "#11111B";
      notification-warning-fg = "#FAE3B0";

      inputbar-fg = "#FFFFFF";
      inputbar-bg = "#11111B";

      recolor = true;
      recolor-lightcolor = "rgba(0,0,0,0.4)";
      recolor-darkcolor = "#FFFFFF";

      index-fg = "#FFFFFF";
      index-bg = "#000000";
      index-active-fg = "#FFFFFF";
      index-active-bg = "#11111B";

      render-loading-bg = "#1E1E2E";
      render-loading-fg = "#FFFFFF";
      highlight-color = "rgba(87,82,104,0.5)";
      highlight-fg = "rgba(245,194,231,0.5)";
      highlight-active-color = "rgba(245,194,231,0.5)";

      # highlight-color = "#575268";
      # highlight-fg = "#F5C2E7";
      # highlight-active-color = "#F5C2E7";
    };
  };
}
