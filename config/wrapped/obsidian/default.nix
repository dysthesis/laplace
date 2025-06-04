{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  mkNixPak = inputs.nixpak.lib.nixpak {
    inherit pkgs lib;
  };
in
mkNixPak {
  config =
    { ... }:
    rec {
      imports = [ ./sandboxing-modules/gui-base.nix ];
      app.package = pkgs.obsidian;
      flatpak.appId = "md.obsidian.Obsidian";
    };
}
