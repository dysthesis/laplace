{
  systemConfig,
  pkgs,
  ...
}: {
  programs.password-store = {
    enable = true;
  };

  home.packages = let
    size =
      if systemConfig.networking.hostName == "yaldabaoth"
      then 8
      else 10;
  in [
    (pkgs.writeScriptBin "dmenu-wl" ''bemenu -b --fn "JetBrainsMono Nerd Font ${toString size}" --fb "#000000" --ff "#ffffff" --nb "#000000" --nf "#ffffff" --tb "#89b4fa" --hb "#000000" --tf "#000000" --hf "#89b4fa" --ab "#000000" -p "󰟵" -H 34 --hp 8'')
  ];
}
