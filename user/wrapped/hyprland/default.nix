{
  hypridle,
  hyprlock,
  hyprland,
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  inherit (lib.babel.pkgs) mkWrapper;

  inherit (lib)
    all
    concatMapStringsSep
    concatStrings
    concatStringsSep
    filterAttrs
    foldl
    generators
    hasPrefix
    isAttrs
    isList
    mapAttrsToList
    replicate
    ;

  # From:
  #   https://github.com/sioodmy/dotfiles/blob/d82f7db5080d0ff4d4920a11378e08df365aeeec/user/wrapped/hypr/tohyprconf.nix
  indentLevel = 0;
  importantPrefixes = [ "$" ];
  initialIndent = concatStrings (replicate indentLevel "  ");

  toHyprconf =
    indent: attrs:
    let
      sections = filterAttrs (_n: v: isAttrs v || (isList v && all isAttrs v)) attrs;

      mkSection' =
        name: attrs:
        if lib.isList attrs then
          concatMapStringsSep "\n" (a: mkSection' name a) attrs
        else
          ''
            ${indent}${name} {
            ${toHyprconf "  ${indent}" attrs}${indent}}
          '';

      mkSection =
        name: attrs:
        if name == "animations" && !lib.isList attrs then
          let
            bezierAttrs = lib.filterAttrs (k: _: builtins.match "bezier" k != null) attrs;
            animationAttrs = lib.filterAttrs (k: _: builtins.match "animation" k != null) attrs;
            otherAttrs = builtins.removeAttrs attrs (lib.attrNames bezierAttrs ++ lib.attrNames animationAttrs);
            renderFields = lib.generators.toKeyValue {
              listsAsDuplicateKeys = true;
              inherit indent;
            };
          in
          ''
            ${indent}animations {
            ${renderFields bezierAttrs}
            ${renderFields animationAttrs}
            ${renderFields otherAttrs}
            ${indent}  }
          ''
        else
          mkSection' name attrs;

      mkFields = generators.toKeyValue {
        listsAsDuplicateKeys = true;
        inherit indent;
      };

      allFields = filterAttrs (_n: v: !(isAttrs v || (isList v && all isAttrs v))) attrs;

      isImportantField =
        n: _: foldl (acc: prev: if hasPrefix prev n then true else acc) false importantPrefixes;

      importantFields = filterAttrs isImportantField allFields;

      fields = builtins.removeAttrs allFields (mapAttrsToList (n: _: n) importantFields);
    in
    mkFields importantFields
    + concatStringsSep "\n" (mapAttrsToList mkSection sections)
    + mkFields fields;

  hypridleConf = pkgs.writeText "hypridle.conf" (
    toHyprconf initialIndent (
      import ./config/hypridle.nix {
        hyprlock = configuredHyprLock;
        inherit lib;
      }
    )
  );

  configuredHyprIdle = mkWrapper pkgs hypridle ''
    wrapProgram $out/bin/hypridle \
      --add-flags "-c ${hypridleConf}"
  '';

  hyprlockConf = pkgs.writeText "hyprlock.conf" (
    toHyprconf initialIndent (import ./config/hyprlock.nix)
  );
  configuredHyprLock = mkWrapper pkgs hyprlock ''
    wrapProgram $out/bin/hyprlock \
      --add-flags "-c ${hyprlockConf}"
  '';

  mkConfig = conf: toHyprconf initialIndent conf |> toString |> pkgs.writeText "hyprland.conf";
  hyprlandConf = mkConfig (
    import ./config {
      inherit
        pkgs
        lib
        config
        hyprland
        inputs
        ;
      hypridle = configuredHyprIdle;
      hyprlock = configuredHyprLock;
    }
  );
in
mkWrapper pkgs hyprland
  # sh
  ''
    wrapProgram $out/bin/Hyprland \
      --add-flags "-c ${hyprlandConf}"
  ''
