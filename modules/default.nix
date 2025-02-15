{lib, ...}: let
  inherit (lib.babel.modules) importInDirectory;
in {
  # Scudo breaks a bunch of apps sadly
  config.environment.memoryAllocator.provider = "libc";
  imports = importInDirectory ./.;
}
