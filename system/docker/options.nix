{ lib, ... }:
let
  inherit (lib) mkEnableOption;
in
{
  options.laplace.docker.enable = mkEnableOption "Whether or not to enable Docker.";
}
