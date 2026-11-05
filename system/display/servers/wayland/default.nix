{
  protocol = "wayland";
  configure = {...}: {
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      _JAVA_AWT_WM_NONEREPARENTING = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    };
  };
}
