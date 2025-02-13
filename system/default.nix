{ lib, ... }:
let
  inherit (lib.babel.modules) importInDirectory;
in
{
  imports = importInDirectory ./.;
}
