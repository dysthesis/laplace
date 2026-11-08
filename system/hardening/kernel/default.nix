{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit
    (lib)
    mkIf
    mkOverride
    mkDefault
    mkForce
    ;
  inherit (builtins) elem;

  cfg = config.laplace.harden;
in {
  config = mkIf (elem "kernel" cfg) {
    security = {
      protectKernelImage = mkForce true; # This disables hibernation.

      # virtd, WireGuard and iptables load modules at runtime.
      # Module locks can prevent boot if necessary modules do not load first.
      lockKernelModules = mkForce false;

      # Limit Meltdown attacks and some KASLR bypasses.
      forcePageTableIsolation = mkForce true;

      # User namespaces are necessary for sandboxing.
      allowUserNamespaces = mkForce true;

      # Rootless Podman must use unprivileged user namespaces.
      unprivilegedUsernsClone = mkDefault true;
    };

    boot = {
      kernelPackages = mkDefault pkgs.linuxPackages_hardened; # The hardened kernel can panic.
      kernelParams = [
        "slab_nomerge"
        "page_poison=1" # Overwrite freed pages.
        "page_alloc.shuffle=1" # Randomise page allocation.
        "debugfs=off"
      ];

      blacklistedKernelModules = [
        # Block uncommon network protocols.
        "ax25"
        "netrom"
        "rose"

        # Block uncommon filesystems and filesystems with limited security review.
        "adfs"
        "affs"
        "bfs"
        "befs"
        "cramfs"
        "efs"
        "erofs"
        "exofs"
        "freevxfs"
        "f2fs"
        "hfs"
        "hpfs"
        "jfs"
        "minix"
        "nilfs2"
        "ntfs"
        "omfs"
        "qnx4"
        "qnx6"
        "sysv"
        "ufs"
      ];

      kernel.sysctl = {
        # Hide kernel pointers even from processes with CAP_SYSLOG.
        "kernel.kptr_restrict" = mkOverride 500 2;

        # Disable BPF JIT compilation to prevent JIT spray attacks.
        # "net.core.bpf_jit_enable" = mkForce false;

        # "kernel.ftrace_enabled" = mkForce false;

        # Reject packets that do not pass strict reverse path filtering. Log them as martians.
        "net.ipv4.conf.all.log_martians" = mkForce true;
        "net.ipv4.conf.all.rp_filter" = mkForce true;
        "net.ipv4.conf.default.log_martians" = mkForce true;
        "net.ipv4.conf.default.rp_filter" = mkForce true;

        # Ignore broadcast ICMP to limit SMURF attacks.
        "net.ipv4.icmp_echo_ignore_broadcasts" = mkForce true;

        # Use the ICMP redirect policy on all current and new interfaces.
        "net.ipv4.conf.all.accept_redirects" = mkForce false;
        "net.ipv4.conf.all.secure_redirects" = mkForce false;
        "net.ipv4.conf.default.accept_redirects" = mkForce false;
        "net.ipv4.conf.default.secure_redirects" = mkForce false;
        "net.ipv6.conf.all.accept_redirects" = mkForce false;
        "net.ipv6.conf.default.accept_redirects" = mkForce false;

        "net.ipv4.conf.all.send_redirects" = mkForce false;
        "net.ipv4.conf.default.send_redirects" = mkForce false;
      };
    };
  };
}
