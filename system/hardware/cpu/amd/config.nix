{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  inherit (builtins) elem;
  cfg = config.laplace.hardware.cpu;
in {
  config = mkIf (elem "amd" cfg) {
    hardware.cpu.amd.updateMicrocode = true;
    boot.kernelModules = [
      "kvm-amd"
      "amd-pstate"
      "zenpower"
      "msr"
    ];
  };
}
