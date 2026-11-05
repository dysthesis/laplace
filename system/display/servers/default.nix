{
  config,
  lib,
  pkgs,
  utils,
  inputs,
  ...
}: let
  desktop = config.laplace.desktop;
  terminal =
    if desktop == null
    then null
    else
      desktop.term.build {
        inherit pkgs lib;
        foot = pkgs.configured.foot;
      };
  launcher =
    if desktop == null || desktop.launcher == null
    then null
    else desktop.launcher.build {inherit pkgs lib;};
  logout =
    if desktop == null || desktop.wm.logout == null
    then null
    else desktop.wm.logout {inherit pkgs lib;};
  barPackage =
    if desktop == null || desktop.bar == null
    then null
    else desktop.bar.build {inherit pkgs lib config;};
  shellPackage =
    if desktop == null || desktop.shell == null
    then null
    else
      desktop.shell.build {
        inherit pkgs lib config logout;
        launcherOpen = launcher.open;
        barEnabled = barPackage == null;
      };
  args = {inherit config lib pkgs utils inputs terminal launcher logout barPackage shellPackage;};
  wm =
    if desktop == null
    then {}
    else desktop.wm.configure args;
  contributions =
    if desktop == null
    then []
    else
      [
        (desktop.server.configure args)
        wm
      ]
      ++ lib.optional (desktop.shell != null) (desktop.shell.configure {
        inherit config lib pkgs utils launcher;
        shell = shellPackage;
      });
  # Fixed option namespaces avoid using config to discover the module import graph.
  field = name: lib.mkMerge (map (part: part.${name} or {}) contributions);
in {
  options.laplace.display.checkCommands = lib.mkOption {
    type = lib.types.listOf lib.types.lines;
    default = [];
    internal = true;
    description = "Validation snippets run by the flake's desktop-stack check.";
  };

  config = {
    laplace = {
      wm =
        if desktop == null
        then null
        else wm.laplace.wm;
      gtk = lib.mkMerge (map (part: part.laplace.gtk or {}) contributions);
      display.checkCommands = lib.concatMap (part: part.laplace.display.checkCommands or []) contributions;
    };
    environment = field "environment";
    programs = field "programs";
    services = field "services";
    systemd = field "systemd";
    users = field "users";
    location = lib.mkIf (desktop != null) {
      latitude = 33.9;
      longitude = 151.2;
    };
  };
}
