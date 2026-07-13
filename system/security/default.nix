{lib, ...}: let
  inherit (lib.laplace.modules) importInDirectory;
in {
  # coredumps are an info leak and slow crashes down
  systemd.coredump.enable = false;
  imports = importInDirectory ./.;
}
