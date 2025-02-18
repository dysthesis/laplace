{inputs, lib, pkgs, ...}: let
  inherit (pkgs) callPackage;
  overlay = _final: _prev: {
    configured = {
      fish = callPackage ./fish {inherit (pkgs) fish;};
    };
  };
in {
  nixpkgs.overlays = [overlay];
}
