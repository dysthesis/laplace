{
  pkgs,
  lib,
  nixosConfigurations,
}: let
  presets = import ../../system/display/presets.nix;
  select = desktopSelection:
    nixosConfigurations.phobos.extendModules {
      specialArgs = {inherit desktopSelection;};
    };
  standalone = select presets.standalone;
  externalBar = select (presets.integrated // {bar = ../../user/wrapped/waybar;});
  empty = select (presets.integrated // {wm = null;});
  sway = select (presets.legacy (import ../../system/display/servers/wayland/compositors/sway));
  managedUnits = host:
    lib.filter
    (name: builtins.elem name ["niri-swallow" "noctalia" "vicinae" "polkit-gnome" "swaybg" "waybar" "dunst"])
    (builtins.attrNames host.config.systemd.user.services);
  noNiri = host:
    !host.config.programs.niri.enable
    && !(host.config.xdg.portal.config ? niri)
    && host.config.services.displayManager.sessionPackages == []
    && !(lib.any (package: (package.pname or package.name or "") == "niri-wrapped") host.config.systemd.packages);
  variants = {inherit standalone externalBar empty sway;};
in {
  desktop-stack = let
    validateHost = name: host:
      lib.optionalString (host.config.laplace.display.checkCommands != []) ''
        echo "validating ${name}"
        ${lib.concatStrings host.config.laplace.display.checkCommands}
      '';
  in
    assert empty.config.laplace.wm == null && managedUnits empty == [] && noNiri empty;
    assert empty.config.laplace.display.checkCommands == [];
    assert empty.config.xdg.portal.config.common == nixosConfigurations.phobos.config.xdg.portal.config.common;
    assert noNiri sway && managedUnits sway == [];
    assert sway.config.laplace.wm.protocol == "wayland" && !sway.config.programs.sway.enable;
    assert managedUnits standalone == ["dunst" "niri-swallow" "swaybg" "waybar"];
    assert managedUnits externalBar == ["niri-swallow" "noctalia" "polkit-gnome" "vicinae" "waybar"];
    assert externalBar.config.systemd.user.services.vicinae.serviceConfig.KillMode == "process";
    assert externalBar.config.systemd.user.services.noctalia.partOf == ["graphical-session.target"];
    assert !externalBar.config.systemd.user.services.niri.enableDefaultPath;
    assert lib.all (host: lib.all (assertion: assertion.assertion) host.config.assertions) (builtins.attrValues variants);
      pkgs.runCommand "desktop-configs" {} ''
        ${lib.concatStrings (lib.mapAttrsToList validateHost nixosConfigurations)}
        ${lib.concatStrings (lib.mapAttrsToList validateHost {inherit standalone externalBar;})}
        export HOME="$TMPDIR/home"
        mkdir -p "$HOME"
        ${lib.getExe pkgs.python3} - \
          ${lib.escapeShellArg nixosConfigurations.phobos.config.systemd.user.services.noctalia.serviceConfig.ExecStart} \
          ${lib.escapeShellArg externalBar.config.systemd.user.services.noctalia.serviceConfig.ExecStart} <<'PY'
        import shlex
        import subprocess
        import sys
        import tomllib

        original, replacement = [
            tomllib.loads(subprocess.check_output(shlex.split(command) + ["config", "export"], text=True))
            for command in sys.argv[1:]
        ]
        assert original["bar"]["main"]["enabled"]
        assert not replacement["bar"]["main"]["enabled"]
        assert replacement["notification"]["enable_daemon"]
        assert replacement["wallpaper"]["enabled"]
        assert {k: v for k, v in original.items() if k != "bar"} == {
            k: v for k, v in replacement.items() if k != "bar"
        }
        PY
        touch $out
      '';

  niri-config = import ./niri-config.nix {
    inherit lib;
    pkgs = nixosConfigurations.deimos.pkgs;
  };

  commit-tools = import ./commit-tools.nix {
    inherit lib;
    pkgs = nixosConfigurations.deimos.pkgs;
  };

  mk-wrapper = let
    argumentCheck = pkgs.writeShellScriptBin "argument check" ''
      test "$#" -eq 2
      test "$1" = "complex command"
      test "$2" = "--literal"
    '';
    wrapped = lib.laplace.pkgs.mkWrapper pkgs argumentCheck {
      program = "argument check";
      addFlags = ["complex command" "--literal"];
    };
    bashWrapped = lib.laplace.pkgs.mkWrapper pkgs pkgs.bash {};
  in
    assert bashWrapped.meta.outputsToInstall == ["out"];
      pkgs.runCommand "mk-wrapper-check" {} ''
        "${wrapped}/bin/argument check"
        test -e ${bashWrapped}/share/man/man1/bash.1.gz
        touch $out
      '';
}
