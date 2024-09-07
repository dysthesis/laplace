{
  services.hyprpaper = let
    wallpaper = "${../wallpaper.png}";
  in {
    enable = true;
    settings = {
      preload = ["${wallpaper}"];
      wallpaper = [",${wallpaper}"];
    };
  };
}
