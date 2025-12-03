{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    mkIf
    ;
  inherit (builtins) elem;
  cfg = config.laplace.hardware.gpu;
in {
  config = mkIf (elem "amd" cfg) {
    services.xserver.videoDrivers = ["amdgpu"];

    boot = {
      initrd.kernelModules = ["amdgpu"];
      kernelModules = ["amdgpu"];
    };
    environment.systemPackages = with pkgs; [
      rocmPackages.rocm-smi
    ];

    nixpkgs.config.rocm.amdgpuGfx = ["gfx1030"];

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        mesa
        vulkan-tools
        vulkan-loader
        vulkan-validation-layers
        vulkan-extension-layer
        rocmPackages.clr
      ];
    };
  };
}
