{ lib, ... }:
let
  inherit (lib.babel.modules) importInDirectory;
in
{
  config.system.stateVersion = "24.11";
  imports = importInDirectory ./.;
}
