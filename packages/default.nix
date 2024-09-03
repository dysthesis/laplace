pkgs: _final: _prev: let
  inherit (pkgs) callPackage;
in {
  sf-pro = callPackage ./sf-pro {};
}
