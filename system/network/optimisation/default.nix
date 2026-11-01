{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.laplace.network.optimise;
in {
  options.laplace.network.optimise = mkEnableOption "Whether or not to enable networking optimisations";
  config = mkIf cfg {
    boot = {
      kernelModules = [
        "tls"
        "tcp_bbr"
      ];
      kernel.sysctl = {
        # Prevent invalid ICMP errors from filling the logs.
        "net.ipv4.icmp_ignore_bogus_error_responses" = true;
        # Validate packet sources to reduce IP spoofing.
        "net.ipv4.conf.default.rp_filter" = true;
        "net.ipv4.conf.all.rp_filter" = true;
        # This host is not a router.
        "net.ipv4.conf.all.accept_source_route" = false;
        "net.ipv6.conf.all.accept_source_route" = false;
        "net.ipv4.conf.all.send_redirects" = false;
        "net.ipv4.conf.default.send_redirects" = false;
        # Reject ICMP redirects to limit man-in-the-middle attacks.
        "net.ipv4.conf.all.accept_redirects" = false;
        "net.ipv4.conf.default.accept_redirects" = false;
        "net.ipv4.conf.all.secure_redirects" = false;
        "net.ipv4.conf.default.secure_redirects" = false;
        "net.ipv6.conf.all.accept_redirects" = false;
        "net.ipv6.conf.default.accept_redirects" = false;
        # Limit SYN flood attacks.
        "net.ipv4.tcp_syncookies" = true;
        # This does not give full protection against TIME-WAIT assassination.
        "net.ipv4.tcp_rfc1337" = true;
        "net.ipv4.conf.all.log_martians" = true;
        "net.ipv4.conf.default.log_martians" = true;
        "net.ipv4.icmp_echo_ignore_broadcasts" = true;
        "net.ipv6.conf.default.accept_ra" = false;
        "net.ipv6.conf.all.accept_ra" = false;
        "net.ipv4.tcp_timestamps" = false;

        # Value 3 enables TCP Fast Open for incoming and outgoing connections.
        "net.ipv4.tcp_fastopen" = 3;
        # Reduce bufferbloat to improve throughput and latency.
        "net.ipv4.tcp_congestion_control" = "bbr";
        "net.core.default_qdisc" = "cake";

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
