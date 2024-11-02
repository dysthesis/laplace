{
  wayland.windowManager.hyprland.settings.windowrulev2 = [
    "workspace 1, class:^(firefox)$"
    "workspace 3, class:^(vesktop)$"
    "workspace 3, class:^(Element)$"
    "workspace 4, class:^(mpv)$"
    "workspace 6, class:^(virt-manager)$"
    "workspace 5, class:^(thunderbird)$"
    "float,title:^(Page Info —.*)$"
    "float,class:thunderbird,title:(Enter credentials for)(.*)"
    "float,class:udiskie"
    "float, title:^(mpv)$"
    "float, title:^(Picture-in-Picture)$"
    "pin, title:^(Picture-in-Picture)$"
    # https://www.reddit.com/r/hyprland/comments/16rwbun/hyprland_issue_with_java_gui/
    "nofocus,class:^ghidra-.+$,title:^win.+$,floating:1,fullscreen:0"
  ];
}
