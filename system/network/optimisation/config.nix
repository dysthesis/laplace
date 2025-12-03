{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.network.optimise;
in {
  config = mkIf cfg {
    # From https://github.com/NotAShelf/nyx/blob/d407b4d6e5ab7f60350af61a3d73a62a5e9ac660/modules/core/common/system/os/networking/optimize.nix
    boot = {
      kernelModules = [
        "tls"
        "tcp_bbr"
      ];
      kernel.sysctl = {
        # TCP hardening
        # Prevent bogus ICMP errors from filling up logs.
        "net.ipv4.icmp_ignore_bogus_error_responses" = true;
        # Reverse path filtering causes the kernel to do source validation of
        # packets received from all interfaces. This can mitigate IP spoofing.
        "net.ipv4.conf.default.rp_filter" = true;
        "net.ipv4.conf.all.rp_filter" = true;
        # Do not accept IP source route packets (we're not a router)
        "net.ipv4.conf.all.accept_source_route" = false;
        "net.ipv6.conf.all.accept_source_route" = false;
        # Don't send ICMP redirects (again, we're on a router)
        "net.ipv4.conf.all.send_redirects" = false;
        "net.ipv4.conf.default.send_redirects" = false;
        # Refuse ICMP redirects (MITM mitigations)
        "net.ipv4.conf.all.accept_redirects" = false;
        "net.ipv4.conf.default.accept_redirects" = false;
        "net.ipv4.conf.all.secure_redirects" = false;
        "net.ipv4.conf.default.secure_redirects" = false;
        "net.ipv6.conf.all.accept_redirects" = false;
        "net.ipv6.conf.default.accept_redirects" = false;
        # Protects against SYN flood attacks
        "net.ipv4.tcp_syncookies" = true;
        # Incomplete protection again TIME-WAIT assassination
        "net.ipv4.tcp_rfc1337" = true;
        # And other stuff
        "net.ipv4.conf.all.log_martians" = true;
        "net.ipv4.conf.default.log_martians" = true;
        "net.ipv4.icmp_echo_ignore_broadcasts" = true;
        "net.ipv6.conf.default.accept_ra" = false;
        "net.ipv6.conf.all.accept_ra" = false;
        "net.ipv4.tcp_timestamps" = false;

        # TCP optimization
        # TCP Fast Open is a TCP extension that reduces network latency by packing
        # data in the sender’s initial TCP SYN. Setting 3 = enable TCP Fast Open for
        # both incoming and outgoing connections:
        "net.ipv4.tcp_fastopen" = 3;
        # Bufferbloat mitigations + slight improvement in throughput & latency
        "net.ipv4.tcp_congestion_control" = "bbr";
        "net.core.default_qdisc" = "cake";

        # Other stuff that I am too lazy to document
        "net.core.optmem_max" = 65536;
        "net.core.rmem_default" = 1048576;
        "net.core.rmem_max" = 16777216;
        "net.core.somaxconn" = 8192;
        "net.core.wmem_default" = 1048576;
        "net.core.wmem_max" = 16777216;
        "net.ipv4.ip_local_port_range" = "16384 65535";
        "net.ipv4.tcp_max_syn_backlog" = 8192;
        "net.ipv4.tcp_max_tw_buckets" = 2000000;
        "net.ipv4.tcp_mtu_probing" = true;
        "net.ipv4.tcp_rmem" = "4096 1048576 2097152";
        "net.ipv4.tcp_slow_start_after_idle" = false;
        "net.ipv4.tcp_tw_reuse" = true;
        "net.ipv4.tcp_wmem" = "4096 65536 16777216";
        "net.ipv4.udp_rmem_min" = 8192;
        "net.ipv4.udp_wmem_min" = 8192;
        "net.netfilter.nf_conntrack_generic_timeout" = 60;
        "net.netfilter.nf_conntrack_max" = 1048576;
        "net.netfilter.nf_conntrack_tcp_timeout_established" = 600;
        "net.netfilter.nf_conntrack_tcp_timeout_time_wait" = true;
      };
    };
  };
}
