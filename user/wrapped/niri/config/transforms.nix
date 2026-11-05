{lib, ...}: let
  inherit (lib) attrByPath concatStringsSep optionalAttrs;

  lookup = attrs: name:
    if builtins.hasAttr name attrs
    then builtins.getAttr name attrs
    else throw "Unknown Niri dependency alias: ${name}";

  resolveCommand = deps: command: args: let
    argv = lookup deps command;
  in
    if
      builtins.isList argv
      && argv != []
      && lib.all builtins.isString argv
      && lib.hasPrefix "/" (builtins.head argv)
      && builtins.isList args
      && lib.all builtins.isString args
    then argv ++ args
    else throw "Niri dependency ${command} requires a non-empty argument vector with an absolute executable and string arguments";

  assertUnique = what: values: result: let
    duplicates = builtins.attrNames (
      lib.filterAttrs (_: group: builtins.length group > 1)
      (builtins.groupBy (value: value) values)
    );
  in
    if duplicates == []
    then result
    else throw "Duplicate Niri ${what}: ${concatStringsSep ", " duplicates}";
in rec {
  resolveAction = deps: action:
    if action.type == "spawn"
    then {
      type = "spawn";
      argv = resolveCommand deps action.command (action.args or []);
    }
    else if action.type == "action"
    then {
      type = "action";
      inherit (action) name;
      args = attrByPath ["args"] [] action;
      options = attrByPath ["options"] {} action;
    }
    else throw "Unsupported Niri action type: ${action.type}";

  resolveBind = deps: bind: let
    options =
      (bind.options or {})
      // optionalAttrs (bind ? title) {
        "hotkey-overlay-title" = bind.title;
      }
      // optionalAttrs (bind.allowWhenLocked or false) {
        "allow-when-locked" = true;
      }
      // optionalAttrs (bind ? repeat) {
        inherit (bind) repeat;
      }
      // optionalAttrs (bind ? cooldownMs) {
        "cooldown-ms" = bind.cooldownMs;
      }
      // optionalAttrs (bind ? allowInhibiting) {
        "allow-inhibiting" = bind.allowInhibiting;
      };
  in {
    inherit (bind) combo;
    inherit options;
    actions = map (resolveAction deps) bind.actions;
  };

  formatMode = monitor: let
    base = "${toString monitor.width}x${toString monitor.height}";
    suffix =
      if monitor ? refreshRate && monitor.refreshRate != null
      then "@${toString monitor.refreshRate}"
      else "";
  in
    base + suffix;

  monitorName = monitor:
    monitor.name or (monitor.connector or "eDP-1");

  monitorPosition = monitor:
    if
      monitor ? pos
      && monitor.pos ? x
      && monitor.pos.x != null
      && monitor.pos ? y
      && monitor.pos.y != null
    then {
      inherit (monitor.pos) x y;
    }
    else null;

  monitorToOutput = monitor: {
    name = monitorName monitor;
    enabled = attrByPath ["enabled"] true monitor;
    mode = formatMode monitor;
    position = monitorPosition monitor;
    scale = attrByPath ["scale"] null monitor;
    variableRefreshRate = attrByPath ["variableRefreshRate"] false monitor;
    focusAtStartup = monitor.primary or false;
  };

  validateModel = model:
    assertUnique "bind combos" (map (bind: bind.combo) model.binds) (
      assertUnique "output names" (map (output: output.name) model.outputs) model
    );
}
