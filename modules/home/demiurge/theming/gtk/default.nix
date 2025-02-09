{
  systemConfig,
  self,
  pkgs,
  ...
}: {
  gtk = {
    enable = true;

    theme = {
      name = "Graphite-Dark";
      package = pkgs.graphite-gtk-theme.override {
        tweaks = ["black" "rimless" "float"];
      };
    };

    # iconTheme = {
    #   name = "Tela-black-dark";
    #   package = pkgs.tela-icon-theme;
    # };

    font = {
      name = "SF Pro Display";
      size =
        if systemConfig.networking.hostName == "yaldabaoth"
        then 8
        else 10;
      package = self.packages.${pkgs.system}.sf-pro;
    };
  };
  home = {
    pointerCursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size =
        if systemConfig.networking.hostName == "yaldabaoth"
        then 18
        else 24;
      gtk.enable = true;
      x11.enable = true;
    };
  };
}
