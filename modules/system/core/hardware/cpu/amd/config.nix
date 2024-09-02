{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.hardware.cpu;
in {
  config = mkIf (cfg == "amd") {
    hardware.cpu.amd.updateMicrocode = true;
    boot.kernelModules = [
      "kvm-amd"
      "amd-pstate"
      "zenpower"
      "msr"
    ];
  };
}
