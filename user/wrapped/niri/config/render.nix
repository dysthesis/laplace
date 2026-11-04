{lib, ...}: let
  inherit (lib) optionalAttrs optionals;

  KDL = import ./kdl.nix {inherit lib;};

  renderFlagOrAssign = flag:
    if builtins.isAttrs flag
    then {
      inline = true;
      assign = flag;
    }
    else flag;

  renderCursor = cursor:
    {
      "xcursor-theme" = cursor.xcursorTheme;
      "xcursor-size" = cursor.xcursorSize;
      "hide-after-inactive-ms" = cursor.hideAfterInactiveMs;
    }
    // optionalAttrs (cursor.hideWhenTyping or false) {
      "hide-when-typing" = true;
    };

  renderInput = input: {
    "focus-follows-mouse" = renderFlagOrAssign input.focusFollowsMouse;
    "workspace-auto-back-and-forth" = input.workspaceAutoBackAndForth or false;
    keyboard.body = {
      numlock = input.keyboard.numlock;
    };
    mouse.body = {
      "natural-scroll" = input.mouse.naturalScroll;
      "accel-speed" = input.mouse.accelSpeed;
      "accel-profile" = input.mouse.accelProfile;
    };
    trackball.body = {
      "natural-scroll" = input.trackball.naturalScroll;
    };
    touchpad.body = {
      tap = input.touchpad.tap;
      dwt = input.touchpad.dwt or false;
      "natural-scroll" = input.touchpad.naturalScroll;
      "disabled-on-external-mouse" = input.touchpad.disabledOnExternalMouse or false;
      "click-method" = {
        inline = true;
        args = [input.touchpad.clickMethod];
      };
    };
  };

  renderLayout = layout:
    {
      inherit (layout) gaps;
      "center-focused-column" = layout.centreFocusedColumn;
      "always-center-single-column" = layout.alwaysCentreSingleColumn;
      "empty-workspace-above-first" = layout.emptyWorkspaceAboveFirst or false;
      "preset-column-widths" = {
        body.proportion = layout.presetColumnWidths.proportions;
      };
      "default-column-width" = {
        body.proportion = layout.defaultColumnWidth.proportion;
      };
      "focus-ring" = {
        body = {
          width = layout.focusRing.width;
          "active-color" = layout.focusRing.activeColour;
          "inactive-color" = layout.focusRing.inactiveColour;
        };
      };
    }
    // optionalAttrs (layout ? presetWindowHeights) {
      "preset-window-heights" = {
        body.proportion = layout.presetWindowHeights.proportions;
      };
    }
    // optionalAttrs (layout ? tabIndicator) {
      "tab-indicator" = {
        body = {
          "hide-when-single-tab" = layout.tabIndicator.hideWhenSingleTab or false;
          "place-within-column" = layout.tabIndicator.placeWithinColumn or false;
          gap = layout.tabIndicator.gap;
          width = layout.tabIndicator.width;
          length = {
            inline = true;
            assign."total-proportion" = layout.tabIndicator.lengthTotalProportion;
          };
          position = layout.tabIndicator.position;
          "gaps-between-tabs" = layout.tabIndicator.gapsBetweenTabs;
          "corner-radius" = layout.tabIndicator.cornerRadius;
          "active-color" = layout.tabIndicator.activeColour;
          "inactive-color" = layout.tabIndicator.inactiveColour;
          "urgent-color" = layout.tabIndicator.urgentColour;
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
    else if action.type == "action"
    then
      KDL.statement {
        inherit (action) name;
        inherit (action) args;
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
            inherit (output) mode;
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

  renderHotkeyOverlay = hotkeyOverlay:
    KDL.block {
      name = "hotkey-overlay";
      body = {
        "skip-at-startup" = hotkeyOverlay.skipAtStartup or false;
        "hide-not-bound" = hotkeyOverlay.hideNotBound or false;
      };
    };

  renderBlur = blur:
    KDL.block {
      name = "blur";
      children =
        optionals (blur.off or false) [
          (KDL.statement {name = "off";})
        ]
        ++ optionals (blur ? passes) [
          (property "passes" blur.passes)
        ]
        ++ optionals (blur ? offset) [
          (property "offset" blur.offset)
        ]
        ++ optionals (blur ? noise) [
          (property "noise" blur.noise)
        ]
        ++ optionals (blur ? saturation) [
          (property "saturation" blur.saturation)
        ];
    };

  renderBackgroundEffect = effect:
    KDL.block {
      name = "background-effect";
      children =
        optionals (effect ? xray) [
          (property "xray" effect.xray)
        ]
        ++ optionals (effect ? blur) [
          (property "blur" effect.blur)
        ]
        ++ optionals (effect ? noise) [
          (property "noise" effect.noise)
        ]
        ++ optionals (effect ? saturation) [
          (property "saturation" effect.saturation)
        ];
    };

  renderMatcher = nodeName: matcher:
    KDL.statement {
      name = nodeName;
      assign =
        optionalAttrs (matcher ? title) {inherit (matcher) title;}
        // optionalAttrs (matcher ? appId) {
          "app-id" = matcher.appId;
        }
        // optionalAttrs (matcher ? isActive) {
          "is-active" = matcher.isActive;
        }
        // optionalAttrs (matcher ? isFocused) {
          "is-focused" = matcher.isFocused;
        }
        // optionalAttrs (matcher ? isActiveInColumn) {
          "is-active-in-column" = matcher.isActiveInColumn;
        }
        // optionalAttrs (matcher ? isFloating) {
          "is-floating" = matcher.isFloating;
        }
        // optionalAttrs (matcher ? isWindowCastTarget) {
          "is-window-cast-target" = matcher.isWindowCastTarget;
        }
        // optionalAttrs (matcher ? isUrgent) {
          "is-urgent" = matcher.isUrgent;
        }
        // optionalAttrs (matcher ? atStartup) {
          "at-startup" = matcher.atStartup;
        };
    };

  renderDimension = name: dimension:
    KDL.block {
      inherit name;
      body =
        optionalAttrs (dimension ? fixed) {inherit (dimension) fixed;}
        // optionalAttrs (dimension ? proportion) {inherit (dimension) proportion;};
    };

  property = name: value:
    KDL.statement {
      inherit name;
      args = [value];
    };

  renderPosition = name: position:
    KDL.statement {
      inherit name;
      assign =
        {
          inherit (position) x y;
        }
        // optionalAttrs (position ? relativeTo) {
          "relative-to" = position.relativeTo;
        };
    };

  renderWindowRule = rule:
    KDL.block {
      name = "window-rule";
      children =
        map (renderMatcher "match") (rule.matches or [{}])
        ++ map (renderMatcher "exclude") (rule.excludes or [])
        ++ optionals (rule ? defaultColumnWidth) [
          (renderDimension "default-column-width" rule.defaultColumnWidth)
        ]
        ++ optionals (rule ? defaultWindowHeight) [
          (renderDimension "default-window-height" rule.defaultWindowHeight)
        ]
        ++ optionals (rule ? defaultFloatingPosition) [
          (renderPosition "default-floating-position" rule.defaultFloatingPosition)
        ]
        ++ optionals (rule ? openOnOutput) [
          (property "open-on-output" rule.openOnOutput)
        ]
        ++ optionals (rule ? openOnWorkspace) [
          (property "open-on-workspace" rule.openOnWorkspace)
        ]
        ++ optionals (rule ? openMaximised) [
          (property "open-maximized" rule.openMaximised)
        ]
        ++ optionals (rule ? openMaximisedToEdges) [
          (property "open-maximized-to-edges" rule.openMaximisedToEdges)
        ]
        ++ optionals (rule ? openFullscreen) [
          (property "open-fullscreen" rule.openFullscreen)
        ]
        ++ optionals (rule ? openFloating) [
          (property "open-floating" rule.openFloating)
        ]
        ++ optionals (rule ? openFocused) [
          (property "open-focused" rule.openFocused)
        ]
        ++ optionals (rule ? blockOutFrom) [
          (property "block-out-from" rule.blockOutFrom)
        ]
        ++ optionals (rule ? variableRefreshRate) [
          (property "variable-refresh-rate" rule.variableRefreshRate)
        ]
        ++ optionals (rule ? defaultColumnDisplay) [
          (property "default-column-display" rule.defaultColumnDisplay)
        ]
        ++ optionals (rule ? scrollFactor) [
          (property "scroll-factor" rule.scrollFactor)
        ]
        ++ optionals (rule ? drawBorderWithBackground) [
          (property "draw-border-with-background" rule.drawBorderWithBackground)
        ]
        ++ optionals (rule ? geometryCornerRadius) [
          (property "geometry-corner-radius" rule.geometryCornerRadius)
        ]
        ++ optionals (rule ? clipToGeometry) [
          (property "clip-to-geometry" rule.clipToGeometry)
        ]
        ++ optionals (rule ? tiledState) [
          (property "tiled-state" rule.tiledState)
        ]
        ++ optionals (rule ? backgroundEffect) [
          (renderBackgroundEffect rule.backgroundEffect)
        ];
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
    ++ optionals (model ? hotkeyOverlay) [
      (renderHotkeyOverlay model.hotkeyOverlay)
    ]
    ++ optionals (model ? blur) [
      (renderBlur model.blur)
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
    ++ map renderWindowRule (model.windowRules or [])
    ++ map renderOutput model.outputs;
in {
  inherit toKdlTree;
  render = model: KDL.render (toKdlTree model);
}
