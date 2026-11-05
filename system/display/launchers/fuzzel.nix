{
  pkgs,
  lib,
}: {
  package = pkgs.configured.fuzzel;
  open = [(lib.getExe pkgs.configured.fuzzel)];
  clipboard = null;
}
