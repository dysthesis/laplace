{lib, ...}:
lib.laplace.modules.mkSelector {
  dir = ./.;
  option = ["laplace" "hardware" "cpu"];
  description = "The manufacturer of the CPU";
}
