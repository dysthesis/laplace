{pkgs, ...}: {
  home.packages = with pkgs; [
    ueberzugpp
    (nerdfonts.override {fonts = ["JetBrainsMono"];})
  ];

  programs.wezterm = {
    enable = true;
    extraConfig = builtins.readFile ./config.lua;
  };
}
