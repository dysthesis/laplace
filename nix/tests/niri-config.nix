{
  lib,
  pkgs,
}: let
  kdl = import ../../user/wrapped/niri/config/kdl.nix {inherit lib;};
  transforms = import ../../user/wrapped/niri/config/transforms.nix {inherit lib;};
  model = import ../../user/wrapped/niri/config/model.nix {inherit lib;};
  renderer = import ../../user/wrapped/niri/config/render.nix {inherit lib;};
  terminal = import ../../user/wrapped/foot/operations.nix {
    inherit pkgs lib;
    foot = pkgs.configured.foot;
  };
  launcher = integrated:
    import (
      if integrated
      then ../../system/display/launchers/vicinae.nix
      else ../../system/display/launchers/fuzzel.nix
    ) {inherit pkgs lib;};
  rejects = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  valid = {
    binds = [{combo = "Mod+A";}];
    outputs = [{name = "eDP-1";}];
  };
  rendered = integrated:
    import ../../user/wrapped/niri/config {
      inherit lib pkgs terminal integrated;
      launcher = launcher integrated;
      shellCommand =
        if integrated
        then [(lib.getExe pkgs.noctalia)]
        else null;
      config.laplace = {
        hardware.monitors = [
          {
            name = "eDP-1";
            width = 2256;
            height = 1504;
            refreshRate = 60.0;
            scale = 1;
            primary = true;
            pos = {
              x = 0;
              y = 0;
            };
          }
        ];
      };
    };

  boundaryArgs = ["two words" "" "quote'\"\\$;\n"];
  boundaryCommand =
    [(lib.getExe pkgs.python3) "-c" "import sys; assert sys.argv[1:] == ${builtins.toJSON boundaryArgs}"]
    ++ boundaryArgs;
  clipboardCommand = (launcher true).clipboard;
  context = {
    integrated = true;
    palette = import ../../system/display/servers/wayland/desktop/palette.nix;
    terminalAppId = terminal.appId;
    monitors = [];
    deps = {
      terminal = terminal.launch;
      launcher = boundaryCommand;
      clipboard = clipboardCommand;
      noctalia = [(lib.getExe pkgs.noctalia)];
      brightnessctl = [(lib.getExe pkgs.brightnessctl)];
      wpctl = [(lib.getExe' pkgs.wireplumber "wpctl")];
      xwaylandSatellite = lib.getExe pkgs.xwayland-satellite;
    };
  };
  integratedModel = model.mkModel context;
  bindCommand = combo: let
    bind = lib.findFirst (bind: bind.combo == combo) (throw "Missing test binding ${combo}") integratedModel.binds;
  in
    (builtins.head bind.actions).argv;
  terminalPattern = appId: let
    standalone = model.mkModel (context
      // {
        integrated = false;
        terminalAppId = appId;
      });
    rule = builtins.head standalone.windowRules;
  in
    (builtins.head rule.matches).appId;
  noctalia = import ../../user/wrapped/noctalia/config.nix {
    inherit lib;
    config = {};
    launcherOpen = boundaryCommand;
    logout = boundaryCommand;
    barEnabled = false;
  };
in
  assert kdl.render [
    (kdl.statement {
      name = "escaped";
      args = ["quote\" slash\\ line\nreturn\rtab\t" ""];
      assign.active = true;
    })
  ]
  == "escaped \"quote\\\" slash\\\\ line\\nreturn\\rtab\\t\" \"\" active=true\n";
  assert rejects (kdl.render [
    (kdl.statement {
      name = "invalid";
      args = [{}];
    })
  ]);
  assert rejects (kdl.render [
    {
      name = "inline";
      inline = true;
      children = [{name = "child";}];
    }
  ]);
  assert transforms.validateModel valid == valid;
  assert rejects (transforms.validateModel (valid // {binds = valid.binds ++ valid.binds;}));
  assert rejects (transforms.validateModel (valid // {outputs = valid.outputs ++ valid.outputs;}));
  assert (transforms.resolveAction {command = boundaryCommand;} {
    type = "spawn";
    command = "command";
    args = ["appended argument" ""];
  }).argv
  == boundaryCommand ++ ["appended argument" ""];
  assert bindCommand "Mod+R" == boundaryCommand;
  assert bindCommand "Mod+Space" == boundaryCommand;
  assert bindCommand "Mod+V" == clipboardCommand;
  assert bindCommand "Mod+N" == [(lib.getExe pkgs.noctalia) "msg" "panel-toggle" "control-center" "notifications"];
  assert lib.all (
    clipboard:
      rejects (renderer.render (model.mkModel (context
        // {
          deps = context.deps // {inherit clipboard;};
        })))
  ) [null [] "" [""] ["relative-clipboard"] ["/clipboard" null] ["/clipboard" 1] ["/clipboard" ["nested"]]];
  assert builtins.match (terminalPattern "foot") "foot" != null;
  assert builtins.match (terminalPattern "foot") "foot.journal" == null;
  assert builtins.match (terminalPattern "foot.journal+[test]") "foot.journal+[test]" != null;
  assert builtins.match (terminalPattern "foot.journal+[test]") "footXjournal+[test]" == null;
    pkgs.runCommand "niri-config-check" {} ''
      NIRI_CONFIG=${rendered false} ${lib.getExe pkgs.niri} validate
      NIRI_CONFIG=${rendered true} ${lib.getExe pkgs.niri} validate
      (${noctalia.widget.apps.actions.left})
      ${(builtins.head noctalia.shell.session.actions).command}
      NIRI_SOCKET=/unused ${lib.getExe pkgs.python3} - ${../../user/wrapped/niri/scripts/niri-swallow.py} 'terminal.with+[literal]' <<'PY'
      import runpy
      import sys

      script = sys.argv.pop(1)
      ancestor_terminal = runpy.run_path(script)["ancestor_terminal"]
      parent = {"id": 1, "pid": 42, "app_id": sys.argv[1]}
      assert ancestor_terminal(42, {1: parent}, 2) == 1
      parent["app_id"] = "foot"
      assert ancestor_terminal(42, {1: parent}, 2) is None
      PY
      touch $out
    ''
