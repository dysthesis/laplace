{desktopSelection, ...}: {
  assertions = [
    {
      assertion =
        desktopSelection.shell
        == null
        && desktopSelection.bar == null
        && desktopSelection.launcher == ../launchers/fuzzel.nix;
      message = "Legacy desktop providers preserve their own launcher/bar startup; component substitutions are supported only by Niri.";
    }
  ];
}
