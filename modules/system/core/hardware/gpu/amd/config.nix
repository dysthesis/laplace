{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkDefault;
  cfg = config.my.hardware.gpu;
in {
  config = mkIf (cfg == "amd") {
    services.xserver.videoDrivers = mkDefault [
      "modesetting"
      "amdgpu"
    ];

    boot = {
      initrd.kernelModules = ["amdgpu"];
      kernelModules = ["amdgpu"];
    };

    hardware.opengl = {
      extraPackages = with pkgs; [
        amdvlk
        mesa
        vulkan-tools
        vulkan-loader
        vulkan-validation-layers
        vulkan-extension-layer
        rocmPackages.clr
      ];

      extraPackages32 = with pkgs; [
        driversi686Linux.amdvlk
      ];
    };
  };
}
