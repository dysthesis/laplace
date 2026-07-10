# On-demand QEMU boot test for the hardened kernel, exposed as the
# `linux-hardened-boot-test` package (deliberately not a flake check: it
# compiles the kernel, so keeping it out of `nix flake check` leaves CI light).
# Run it with:  nix build .#linux-hardened-boot-test
#
# Boots linux_hardened in a QEMU VM via nixpkgs' own NixOS test framework — no
# extra flake inputs (the stdlib already does VM boot tests, so microvm.nix
# would be redundant moving parts for the same goal). A clean boot to
# multi-user.target already proves the patched kernel built, that modDirVersion
# matched (else modules would not load), and that the hardening config did not
# brick boot; the assertions then pin down that it is the right kernel.
{pkgs}:
pkgs.testers.runNixOSTest {
  name = "linux-hardened-boot";

  nodes.machine = {
    boot.kernelPackages = pkgs.linuxPackages_hardened;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # The patched kernel booted: EXTRAVERSION=-hardened1 yields this exact
    # release string, which only the overlay produces.
    machine.succeed("test \"$(uname -r)\" = '7.1.0-hardened1'")

    # config.nix took effect, not just any 7.1 kernel: PROC_KCORE=no removes
    # /proc/kcore, which is present on a stock NixOS kernel.
    machine.succeed("test ! -e /proc/kcore")
  '';
}
