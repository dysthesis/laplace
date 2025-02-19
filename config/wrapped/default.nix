{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs) callPackage;
  overlay = _final: _prev: {
    configured = {
      fish = callPackage ./fish {
        inherit (pkgs) fish;
        inherit pkgs inputs;
      };
      bash = callPackage ./bash { inherit pkgs lib; };
    };
  };
in
{
  nixpkgs.overlays = [ overlay ];
}
