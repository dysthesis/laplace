{lib, ...}: let
  inherit (lib.laplace.modules) importNixInDirectory;
in {
  imports = importNixInDirectory "default.nix" ./.;
}
