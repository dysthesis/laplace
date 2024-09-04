{lib, ...}: let
  inherit
    (builtins)
    readDir
    attrNames
    ;
  inherit
    (lib)
    filter
    hasSuffix
    filterAttrs
    ;
in {
  wayland.windowManager.hyprland.enable = true;

  # Import all Nix files in the current directory
  imports = let
    inCwd = filterAttrs isFile (readDir ./.);
    isNixFile = file: hasSuffix ".nix" file;
    isFile = _: value: value == "regular";
  in
    map
    (file: ./${file})
    (filter
      (name: name != "default.nix" && isNixFile name)
      (attrNames inCwd));
}
