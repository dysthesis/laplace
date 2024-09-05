{pkgs, ...}: {
  home.packages = [(pkgs.nerdfonts.override {fonts = ["JetBrainsMono"];})];

  programs.bemenu = {
    enable = true;
    settings = {
      ignorecase = true;
      bottom = true;
      line-height = 34;
      prompt = "";
      # Horizontal padding
      hp = 8;
      fn = "JetBrainsMono Nerd Font 10";
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
