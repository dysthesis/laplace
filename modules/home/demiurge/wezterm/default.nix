{
  config,
  lib,
  inputs,
  systemConfig,
  pkgs,
  ...
}: let
  inherit
    (lib)
    fold
    toLower
    ;
in {
  home.packages = with pkgs; [
    wl-clipboard
    ueberzugpp
    nerd-fonts.jetbrains-mono
  ];

  programs.wezterm = let
    fontSize =
      if systemConfig.networking.hostName == "yaldabaoth"
      then 8
      else 10;
  in
    {
      enable = false;
      package = inputs.wezterm.packages.${pkgs.system}.default;
      extraConfig =
        /*
        lua
        */
        ''
          local size = ${toString fontSize}
          ${builtins.readFile ./config.lua}
        '';
    }
    # Automatically enable integration with any enabled shells
    // fold
    (curr: acc:
      acc
      // {"enable${curr}Integration" = config.programs.${toLower curr}.enable;})
    {}
    ["Zsh" "Bash"];
}
