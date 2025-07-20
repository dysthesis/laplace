{ lib, ... }:
let
  inherit (lib) mkEnableOption;
in
{
  options.laplace.services.searxng.enable = mkEnableOption "Whether or not to enable SearXNG";
}
