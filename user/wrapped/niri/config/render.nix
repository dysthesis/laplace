{lib, ...}: let
  inherit (lib) optionalAttrs optionals;

  KDL = import ./kdl.nix {inherit lib;};

  renderCursor = cursor: {
    "xcursor-theme" = cursor.xcursorTheme;
    "xcursor-size" = cursor.xcursorSize;
    "hide-after-inactive-ms" = cursor.hideAfterInactiveMs;
  };

  renderInput = input: {
    "focus-follows-mouse" = input.focusFollowsMouse;
    keyboard = {
      numlock = input.keyboard.numlock;
    };
    mouse = {
      "natural-scroll" = input.mouse.naturalScroll;
      "accel-speed" = input.mouse.accelSpeed;
      "accel-profile" = input.mouse.accelProfile;
    };
    touchpad = {
      tap = input.touchpad.tap;
      "natural-scroll" = input.touchpad.naturalScroll;
      "click-method" = {
        inline = true;
        args = [input.touchpad.clickMethod];
      };
    };
  };

  renderLayout = layout: {
    gaps = layout.gaps;
    "center-focused-column" = layout.centerFocusedColumn;
    "always-center-single-column" = layout.alwaysCenterSingleColumn;
    "preset-column-widths" = {
      body.proportion = layout.presetColumnWidths.proportions;
    };
    "default-column-width" = {
      body.proportion = layout.defaultColumnWidth.proportion;
    };
    "focus-ring" = {
      body = {
        width = layout.focusRing.width;
        "active-color" = layout.focusRing.activeColor;
        "inactive-color" = layout.focusRing.inactiveColor;
      };
    };
  };

  renderAction = action:
    if action.type == "spawn"
    then
      KDL.statement {
        name = "spawn";
        args = action.argv;
      }
    else if action.type == "spawn-sh"
    then
      KDL.statement {
        name = "spawn-sh";
        args = [action.script];
      }
    else if action.type == "action"
    then
      KDL.statement {
        inherit (action) name;
        args = action.args;
        assign = action.options;
      }
    else throw "Unsupported resolved Niri action type: ${action.type}";

  renderBind = bind:
    KDL.block {
      name = bind.combo;
      assign = bind.options;
      children = map renderAction bind.actions;
    };

  renderOutput = output:
    KDL.block {
      name = "output";
      args = [output.name];
      body =
        if !output.enabled
        then {off = true;}
        else
          {
            mode = output.mode;
          }
          // optionalAttrs (output.scale != null) {
            inherit (output) scale;
          }
          // optionalAttrs (output.position != null) {
            position = {
              inline = true;
              assign = output.position;
            };
          }
          // optionalAttrs output.variableRefreshRate {
            "variable-refresh-rate" = true;
          }
          // optionalAttrs output.focusAtStartup {
            "focus-at-startup" = true;
          };
    };

  renderStartup = command:
    KDL.statement {
      name = "spawn-at-startup";
      args = command.argv;
    };

  toKdlTree = model:
    [
      (KDL.block {
        name = "environment";
        body = model.environment;
      })
      (KDL.block {
        name = "cursor";
        body = renderCursor model.cursor;
      })
      (KDL.block {
        name = "input";
        body = renderInput model.input;
      })
      (KDL.statement {
        name = "screenshot-path";
        args = [model.screenshotPath];
      })
      (KDL.block {
        name = "layout";
        body = renderLayout model.layout;
      })
    ]
    ++ optionals model.preferNoCsd [
      (KDL.statement {name = "prefer-no-csd";})
    ]
    ++ [
      (KDL.block {
        name = "xwayland-satellite";
        body.path = model.xwaylandSatellite;
      })
      (KDL.block {
        name = "binds";
        children = map renderBind model.binds;
      })
    ]
    ++ map renderOutput model.outputs
    ++ map renderStartup model.startup;
in {
  inherit toKdlTree;
  render = model: KDL.render (toKdlTree model);
}
