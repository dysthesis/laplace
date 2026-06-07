{lib, ...}:
lib.laplace.modules.mkSelector {
  dir = ./.;
  option = ["laplace" "profiles"];
  description = "Which system profiles to enable";
}
