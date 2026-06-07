{lib, ...}:
lib.laplace.modules.mkSelector {
  dir = ./.;
  option = ["laplace" "hardware" "gpu"];
  description = "The manufacturer of the GPU";
}
