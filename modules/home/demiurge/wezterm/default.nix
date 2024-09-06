{
  inputs,
  systemConfig,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    ueberzugpp
    (nerdfonts.override {fonts = ["JetBrainsMono"];})
  ];

  programs.wezterm = let
    fontSize =
      if systemConfig.networking.hostName == "yaldabaoth"
      then 8
      else 10;
  in {
    enable = true;
    package = inputs.wezterm.packages.${pkgs.system}.default;
    extraConfig =
      /*
      lua
      */
      ''
        local size = ${toString fontSize}
        ${builtins.readFile ./config.lua}
      '';
  };
}
