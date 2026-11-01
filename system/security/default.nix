{lib, ...}: let
  inherit (lib.laplace.modules) importInDirectory;
in {
  # Core dumps can expose data and delay process termination.
  systemd.coredump.enable = false;
  # https://emudhra.we-have-a-problem.com/
  security.pki.caCertificateBlacklist = [
    "Comodo AAA Services root"
    "emSign ECC Root CA - G3"
  ];
  imports = importInDirectory ./.;
}
