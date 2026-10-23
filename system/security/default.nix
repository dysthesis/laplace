{lib, ...}: let
  inherit (lib.laplace.modules) importInDirectory;
in {
  # coredumps are an info leak and slow crashes down
  systemd.coredump.enable = false;
  # https://emudhra.we-have-a-problem.com/
  security.pki.caCertificateBlacklist = [
    "Comodo AAA Services root"
    "emSign ECC Root CA - G3"
  ];
  imports = importInDirectory ./.;
}
