# Flake-local package overlay.
#
# Font packages vendored from the (deprecated) nixpressions flake. Only the
# fonts the desktop profile actually consumes are kept.
final: _prev: {
  fast-fonts = final.callPackage ./fast-fonts {};
  sf-pro = final.callPackage ./sf-pro {};
  georgia-fonts = final.callPackage ./georgia-fonts {};
  jbcustom-nf = final.callPackage ./jbcustom-nf {};
  literata = final.callPackage ./literata {};
}
