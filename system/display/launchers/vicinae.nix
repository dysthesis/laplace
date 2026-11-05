{
  pkgs,
  lib,
}: {
  package = pkgs.configured.vicinae;
  open = [(lib.getExe pkgs.configured.vicinae) "toggle"];
  clipboard = [(lib.getExe pkgs.configured.vicinae) "vicinae://launch/clipboard/history"];
}
