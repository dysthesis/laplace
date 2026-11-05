{
  pkgs,
  lib,
  nixosConfigurations,
}: let
  components = lib.components;
  standaloneSelection = {
    server = components.wayland;
    wm = components.niri;
    term = components.foot;
    bar = components.waybar;
    launcher = components.fuzzel;
  };
  integratedSelection = {
    server = components.wayland;
    wm = components.niri;
    term = components.foot;
    shell = components.noctalia;
    launcher = components.vicinae;
  };
  swaySelection = {
    server = components.wayland;
    wm = components.sway;
    term = components.foot;
  };
  select = selected:
    nixosConfigurations.phobos.extendModules {
      modules = [{laplace.desktop = lib.mkForce selected;}];
    };
  standalone = select standaloneSelection;
  externalBar = select (integratedSelection // {bar = components.waybar;});
  empty = select null;
  sway = select swaySelection;
  withoutDesktopProfile = (select integratedSelection).extendModules {
    modules = [{laplace.profiles = lib.mkForce [];}];
  };
  rejected = host: !(builtins.tryEval (builtins.deepSeq host.config.laplace.desktop true)).success;
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
    assert rejected withoutDesktopProfile;
    assert rejected (select (swaySelection // {server = components.xorg;}));
    assert rejected (select (integratedSelection // {launcher = null;}));
    assert rejected (select (integratedSelection // {launcher = components.fuzzel;}));
    assert rejected (select (swaySelection // {bar = components.waybar;}));
    assert empty.config.laplace.desktop == null;
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
        export XDG_STATE_HOME="$TMPDIR/state"
        mkdir -p "$HOME"
        ${lib.getExe pkgs.python3} - \
          ${lib.escapeShellArg nixosConfigurations.phobos.config.systemd.user.services.noctalia.serviceConfig.ExecStart} \
          ${lib.escapeShellArg externalBar.config.systemd.user.services.noctalia.serviceConfig.ExecStart} <<'PY'
        import shlex
        import os
        from pathlib import Path
        import subprocess
        import sys
        import tomllib

        def export(command):
            return tomllib.loads(subprocess.check_output(
                shlex.split(command) + ["config", "export", "full"], text=True,
            ))

        original, replacement = [export(command) for command in sys.argv[1:]]
        assert original["bar"]["main"]["enabled"]
        assert not replacement["bar"]["main"]["enabled"]
        assert replacement["notification"]["enable_daemon"]
        assert replacement["wallpaper"]["enabled"]
        assert {k: v for k, v in original.items() if k != "bar"} == {
            k: v for k, v in replacement.items() if k != "bar"
        }
        settings = Path(os.environ["XDG_STATE_HOME"]) / "noctalia/settings.toml"
        settings.parent.mkdir(parents=True)
        saved = """[bar.main]
        enabled = true
        [bar.main.monitor."*"]
        enabled = true
        [bar.extra]
        enabled = true
        [shell]
        font_family = "Saved desktop font"
        """
        settings.write_text(saved)
        persisted = export(sys.argv[2])
        for name in persisted["bar"]["order"]:
            bar = persisted["bar"][name]
            assert not bar["enabled"], name
            assert all(not monitor["enabled"] for monitor in bar.get("monitor", {}).values()), name
        assert persisted["shell"]["font_family"] == "Saved desktop font"
        assert persisted["notification"]["enable_daemon"]
        assert persisted["wallpaper"]["enabled"]
        assert settings.read_text() == saved
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
