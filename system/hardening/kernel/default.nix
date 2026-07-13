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
    # from https://github.com/NotAShelf/nyx/blob/319b1f6fe4d09ff84d83d1f8fa0d04e0220dfed7/modules/core/common/system/security/kernel.nix#L57
    security = {
      protectKernelImage = mkForce true; # disables hibernation

      # off: breaks virtd, wireguard, iptables (they load modules at runtime);
      # enabling without every needed module declared can make the system unbootable
      lockKernelModules = mkForce false;

      # mitigates Meltdown and some KASLR bypasses
      forcePageTableIsolation = mkForce true;

      # required for sandboxing
      allowUserNamespaces = mkForce true;

      # podman rootless needs unprivileged userns
      unprivilegedUsernsClone = mkDefault true;
    };

    boot = {
      kernelPackages = mkDefault pkgs.linuxPackages_hardened; # BUG: causes kernel panic
      kernelParams = [
        "slab_nomerge"
        "page_poison=1" # overwrite freed pages
        "page_alloc.shuffle=1" # randomise page allocator
        "debugfs=off"
      ];

      blacklistedKernelModules = [
        # Obscure network protocols
        "ax25"
        "netrom"
        "rose"

        # Old or rare or insufficiently audited filesystems
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

      # mkForce: hardening, when enabled, should override everything else.
      kernel.sysctl = {
        # hide kptrs even from CAP_SYSLOG
        "kernel.kptr_restrict" = mkOverride 500 2;

        # no bpf() JIT (eliminates spray attacks)
        "net.core.bpf_jit_enable" = mkForce false;

        "kernel.ftrace_enabled" = mkForce false;

        # Enable strict reverse path filtering (that is, do not attempt to route
        # packets that "obviously" do not belong to the iface's network; dropped
        # packets are logged as martians).
        "net.ipv4.conf.all.log_martians" = mkForce true;
        "net.ipv4.conf.all.rp_filter" = mkForce true;
        "net.ipv4.conf.default.log_martians" = mkForce true;
        "net.ipv4.conf.default.rp_filter" = mkForce true;

        # Ignore broadcast ICMP (mitigate SMURF)
        "net.ipv4.icmp_echo_ignore_broadcasts" = mkForce true;

        # Ignore incoming ICMP redirects (note: default is needed to ensure that the
        # setting is applied to interfaces added after the sysctls are set)
        "net.ipv4.conf.all.accept_redirects" = mkForce false;
        "net.ipv4.conf.all.secure_redirects" = mkForce false;
        "net.ipv4.conf.default.accept_redirects" = mkForce false;
        "net.ipv4.conf.default.secure_redirects" = mkForce false;
        "net.ipv6.conf.all.accept_redirects" = mkForce false;
        "net.ipv6.conf.default.accept_redirects" = mkForce false;

        # Ignore outgoing ICMP redirects (this is ipv4 only)
        "net.ipv4.conf.all.send_redirects" = mkForce false;
        "net.ipv4.conf.default.send_redirects" = mkForce false;
      };
    };
  };
}
