{lib, ...}:
lib.laplace.modules.mkSelector {
  dir = ./.;
  option = ["laplace" "filesystems"];
  description = "Which filesystems to enable support for";
}
