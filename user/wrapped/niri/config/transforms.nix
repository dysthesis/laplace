{lib, ...}: let
  inherit (lib) concatStringsSep optionalAttrs optionals unique;

  lookup = attrs: name:
    if builtins.hasAttr name attrs
    then builtins.getAttr name attrs
    else throw "Unknown Niri dependency alias: ${name}";

  isReference = value: builtins.isAttrs value && value ? ref;

  resolveArg = deps: arg:
    if isReference arg
    then lookup deps arg.ref
    else if builtins.isAttrs arg
    then throw "Unsupported Niri command argument: ${builtins.toJSON arg}"
    else arg;

  resolveCommand = deps: command: args:
    [(lookup deps command)] ++ map (resolveArg deps) args;

  duplicateValues = values:
    if values == []
    then []
    else let
      first = builtins.head values;
      rest = builtins.tail values;
    in
      optionals (builtins.elem first rest) [first] ++ duplicateValues rest;

  assertUnique = what: values: result: let
    duplicates = unique (duplicateValues values);
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
    else if action.type == "spawn-sh"
    then {
      type = "spawn-sh";
      inherit (action) script;
    }
    else if action.type == "action"
    then {
      type = "action";
      inherit (action) name;
      args = action.args or [];
      options = action.options or {};
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

  resolveStartup = deps: entry: {
    argv = resolveCommand deps entry.command (entry.args or []);
  };

  locationToStartup = {
    deps,
    location,
    ...
  }:
    optionals ((location.latitude != 0) || (location.longitude != 0)) [
      {
        argv = [
          (lookup deps "wlsunset")
          "-t"
          "3700"
          "-T"
          "6200"
          "-g"
          "1.0"
          "-l"
          (toString location.latitude)
          "-L"
          (toString location.longitude)
        ];
      }
    ];

  formatMode = monitor: let
    base = "${toString monitor.width}x${toString monitor.height}";
    suffix =
      if monitor ? refreshRate && monitor.refreshRate != null
      then "@${toString monitor.refreshRate}"
      else "";
  in
    base + suffix;

  monitorName = monitor:
    if monitor ? name
    then monitor.name
    else if monitor ? connector
    then monitor.connector
    else "eDP-1";

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
    enabled = monitor.enabled or true;
    mode = formatMode monitor;
    position = monitorPosition monitor;
    scale =
      if monitor ? scale
      then monitor.scale
      else null;
    variableRefreshRate = monitor.variableRefreshRate or false;
    focusAtStartup = monitor.primary or false;
  };

  validateModel = model:
    assertUnique "bind combos" (map (bind: bind.combo) model.binds) (
      assertUnique "output names" (map (output: output.name) model.outputs) model
    );
}
