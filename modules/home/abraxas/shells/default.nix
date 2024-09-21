{lib, ...}: let
  inherit (lib.laplace.modules) importInDirectory;
in {
  imports = importInDirectory ./.;
}
