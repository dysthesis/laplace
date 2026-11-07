{lib, ...}: let
  inherit (lib.laplace.modules) importInDirectory;
in {
  # Core dumps can expose data and delay process termination.
  systemd.coredump.enable = false;
  security.pki.caCertificateBlacklist = [
    "Comodo AAA Services root"
  ];
  imports = importInDirectory ./.;
}
