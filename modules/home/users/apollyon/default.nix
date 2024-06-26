{
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; {
  # Let home-manager manage itself
  programs.home-manager.enable = true;

  home = {
    username = "apollyon";
    homeDirectory = "/home/apollyon";
    stateVersion = "23.11";
  };

  imports = [
    ./hyprland
    ./helix
    # ./ags
    ./khal
    ./waybar
    ./dunst
    ./wezterm
    ./shell
    ./anyrun
    ./theme
    ./git
    ./services
    ./vencord
    ./firefox
    ./emacs
    ./yazi
    ./mpd
    ./xdg
    ./swaylock
    ./wlogout
    ./btop
    ./zoxide
    ./zellij
    ./lazygit
    ./bat
    ./zathura
    ./media
    ../../options
  ];

  myHome = {
    monitors = [
      {
        name = "DP-1";
        width = 1920;
        height = 1080;
        refreshRate = 60;
        x = 0;
        y = 0;
      }
      {
        name = "DP-2";
        width = 1920;
        height = 1080;
        refreshRate = 165;
        x = 1920;
        y = 0;
      }
    ];
    wallpaper = ../../shared/wallpapers/wallhaven-6dwmmw.png;
  };

  home = {
    # Standalone packages that do not belong to any modules
    # do not put packages here if possible, since having proper
    # modules can provide useful context.
    packages = with pkgs; [
      git
      freetube
      tor-browser
      signal-desktop
      pcmanfm
      keepassxc
      thunderbird
      zotero
      element-desktop
      # obsidian
      libreoffice
      qbittorrent
      # obs-studio
      protonvpn-gui
      gnome.gnome-disk-utility
      alejandra
      neovide
      weechat
      nsxiv
      brave
      inputs.poincare.packages.x86_64-linux.default
      # inputs.nixvim.packages.x86_64-linux.default #temporarily broken: https://github.com/nix-community/nixvim/issues/1160
      (nerdfonts.override {fonts = ["JetBrainsMono"];})
    ];

    sessionVariables = {
      BROWSER = "${lib.getExe pkgs.firefox}";
    };

    #persistence."/nix/persist/home/apollyon" = {
    #  allowOther = true;
    #  directories =
    #    [
    #      "Org"
    #      "Zotero"
    #      "Downloads"
    #      "Documents"
    #      "Music"
    #      "Pictures"
    #      ".ssh"
    #      ".gnupg"
    #    ]
    #    # .config directories to persist
    #    ++ forEach [
    #      "FreeTube"
    #      "emacs"
    #      "doom"
    #      "VencordDesktop"
    #    ] (x: ".config/${x}");
    #};
  };
}
