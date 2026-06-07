{lib, ...}:
lib.babel.modules.mkSelector {
  dir = ./.;
  option = ["laplace" "harden"];
  description = "Which hardening profiles to enable";
}
