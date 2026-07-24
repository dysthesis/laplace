# On-demand QEMU test, kept out of flake check because it builds a kernel.
# Boot proves the patch, module version, and hardening config work together.
{pkgs}:
pkgs.testers.runNixOSTest {
  name = "linux-hardened-boot";

  nodes.machine = {
    boot.kernelPackages = pkgs.linuxPackages_hardened;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # EXTRAVERSION proves the patched kernel booted.
    machine.succeed("test \"$(uname -r)\" = '7.1.0-hardened1'")

    # Missing /proc/kcore proves PROC_KCORE is disabled.
    machine.succeed("test ! -e /proc/kcore")
  '';
}
