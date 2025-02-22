{
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (lib)
    mkIf
    mkOverride
    mkDefault
    mkForce
    ;
  inherit (builtins) elem;

  cfg = config.laplace.harden;
in
{
  config = mkIf (elem "kernel" cfg) {
    # This section is stolen from https://github.com/NotAShelf/nyx/blob/319b1f6fe4d09ff84d83d1f8fa0d04e0220dfed7/modules/core/common/system/security/kernel.nix#L57
    security = {
      protectKernelImage = mkForce true; # disables hibernation

      # Breaks virtd, wireguard and iptables by disallowing them from loading
      # modules during runtime. You may enable this module if you wish, but do
      # make sure that the necessary modules are loaded declaratively before
      # doing so. Failing to add those modules may result in an unbootable system!
      lockKernelModules = mkForce false;

      # Force-enable the Page Table Isolation (PTI) Linux kernel feature
      # helps mitigate Meltdown and prevent some KASLR bypasses.
      forcePageTableIsolation = mkForce true;

      # User namespaces are required for sandboxing. Better than nothing imo.
      allowUserNamespaces = mkForce true;

      # Disable unprivileged user namespaces, unless containers are enabled
      # required by podman to run containers in rootless mode.
      unprivilegedUsernsClone = mkDefault true;
    };

    boot = {
      kernelPackages = mkDefault pkgs.linuxPackages_hardened;
      kernelParams = [
        # Don't merge slabs
        "slab_nomerge"

        # Overwrite free'd pages
        "page_poison=1"

        # Enable page allocator randomization
        "page_alloc.shuffle=1"

        # Disable debugfs
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

      # Setting these to mkForce since I think guaranteeing that hardening options
      # apply when enabled is more important than anything else. Hardening should
      # override all other options.
      # Hide kptrs even for processes with CAP_SYSLOG
      kernel.sysctl = {
        "kernel.kptr_restrict" = mkOverride 500 2;

        # Disable bpf() JIT (to eliminate spray attacks)
        "net.core.bpf_jit_enable" = mkForce false;

        # Disable ftrace debugging
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
