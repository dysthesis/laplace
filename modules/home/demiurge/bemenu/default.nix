{
  systemConfig,
  pkgs,
  ...
}: let
  fontSize =
    if systemConfig.networking.hostName == "yaldabaoth"
    then 8
    else 9;
  line-height =
    if systemConfig.networking.hostName == "yaldabaoth"
    then 28
    else 34;
in {
  home.packages = [pkgs.nerd-fonts.jetbrains-mono];

  programs.bemenu = {
    enable = true;
    settings = {
      inherit line-height;
      ignorecase = true;
      bottom = true;
      prompt = "";
      fn = "JetBrainsMono Nerd Font ${toString fontSize}";
      # Horizontal padding
      hp = 8;
      fb = "#000000";
      ff = "#ffffff";
      nb = "#000000";
      nf = "#ffffff";
      tb = "#89b4fa";
      hb = "#11111b";
      tf = "#000000";
      hf = "#89b4fa";
      ab = "#000000";
    };
  };
}
