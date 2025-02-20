{
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./installer.nix
  ];
  environment.systemPackages = let
    inherit
      (pkgs)
      writeText
      symlinkJoin
      makeWrapper
      system
      ;
    ghostty-config = writeText "ghostty-config" ''
      adjust-cell-height = 20%
      font-family = JetBrainsMono Nerd Font
      font-feature = calt
      font-feature = clig
      font-feature = liga
      font-feature = ss20
      font-feature = cv02
      font-feature = cv03
      font-feature = cv04
      font-feature = cv05
      font-feature = cv06
      font-feature = cv07
      font-feature = cv11
      font-feature = cv14
      font-feature = cv15
      font-feature = cv16
      font-feature = cv17
      font-size = 10
      window-padding-x = 20
      window-padding-y = 20

      ## Lackluster
      # https://github.com/slugbyte/lackluster.nvim/blob/662fba7e6719b7afc155076385c00d79290bc347/extra/ghostty/lackluster

      palette = 0=#080808
      palette = 1=#d70000
      palette = 2=#789978
      palette = 3=#ffaa88
      palette = 4=#7788aa
      palette = 5=#d7007d
      palette = 6=#708090
      palette = 7=#deeeed
      palette = 8=#444444
      palette = 9=#d70000
      palette = 10=#789978
      palette = 11=#ffaa88
      palette = 12=#7788aa
      palette = 13=#d7007d
      palette = 14=#708090
      palette = 15=#deeeed
      background = 000000
      foreground = deeeed
      cursor-color = deeeed
      selection-background = 7a7a7a
      selection-foreground = 0a0a0a
    '';
    ghostty-wrapped = symlinkJoin {
      name = "ghostty-wrapped";
      paths = [
        inputs.babel.packages.${system}.ghostty-hardened
      ];
      buildInputs = [makeWrapper];
      postBuild =
        # sh
        ''
          wrapProgram $out/bin/ghostty --add-flags "--config-file=${ghostty-config}"
        '';
    };
  in
    with pkgs; [
      inputs.disko.packages.${system}.default
      inputs.daedalus.packages.${system}.default
      inputs.poincare.packages.${system}.default
      ghostty-wrapped
      (nerdfonts.override {
        fonts = ["JetBrainsMono"];
      })
      btop
      just
      microfetch
    ];

  documentation = {
    enable = lib.mkForce false;
    man.enable = lib.mkForce false;
    doc.enable = lib.mkForce false;
    info.enable = lib.mkForce false;
    nixos.enable = lib.mkForce false;
  };

  boot.initrd = {
    compressor = "zstd";
    compressorArgs = [
      "-19"
      "-T0"
    ];
    systemd.enable = true;
  };

  isoImage = {
    edition = lib.mkForce "erebus";
    isoName = lib.mkForce "NixOS";
  };
  # From https://github.com/NotAShelf/nyx/blob/d407b4d6e5ab7f60350af61a3d73a62a5e9ac660/modules/core/common/system/os/networking/optimize.nix
  zramSwap.enable = true;
  boot = {
    kernelModules = ["tls" "tcp_bbr"];
    kernel.sysctl = {
      # TCP hardening
      # Prevent bogus ICMP errors from filling up logs.
      "net.ipv4.icmp_ignore_bogus_error_responses" = 1;
      # Reverse path filtering causes the kernel to do source validation of
      # packets received from all interfaces. This can mitigate IP spoofing.
      "net.ipv4.conf.default.rp_filter" = 1;
      "net.ipv4.conf.all.rp_filter" = 1;
      # Do not accept IP source route packets (we're not a router)
      "net.ipv4.conf.all.accept_source_route" = 0;
      "net.ipv6.conf.all.accept_source_route" = 0;
      # Don't send ICMP redirects (again, we're on a router)
      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;
      # Refuse ICMP redirects (MITM mitigations)
      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.default.accept_redirects" = 0;
      "net.ipv4.conf.all.secure_redirects" = 0;
      "net.ipv4.conf.default.secure_redirects" = 0;
      "net.ipv6.conf.all.accept_redirects" = 0;
      "net.ipv6.conf.default.accept_redirects" = 0;
      # Protects against SYN flood attacks
      "net.ipv4.tcp_syncookies" = 1;
      # Incomplete protection again TIME-WAIT assassination
      "net.ipv4.tcp_rfc1337" = 1;
      # And other stuff
      "net.ipv4.conf.all.log_martians" = true;
      "net.ipv4.conf.default.log_martians" = true;
      "net.ipv4.icmp_echo_ignore_broadcasts" = true;
      "net.ipv6.conf.default.accept_ra" = 0;
      "net.ipv6.conf.all.accept_ra" = 0;
      "net.ipv4.tcp_timestamps" = 0;

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
      "net.ipv4.tcp_mtu_probing" = 1;
      "net.ipv4.tcp_rmem" = "4096 1048576 2097152";
      "net.ipv4.tcp_slow_start_after_idle" = 0;
      "net.ipv4.tcp_tw_reuse" = 1;
      "net.ipv4.tcp_wmem" = "4096 65536 16777216";
      "net.ipv4.udp_rmem_min" = 8192;
      "net.ipv4.udp_wmem_min" = 8192;
      "net.netfilter.nf_conntrack_generic_timeout" = 60;
      "net.netfilter.nf_conntrack_max" = 1048576;
      "net.netfilter.nf_conntrack_tcp_timeout_established" = 600;
      "net.netfilter.nf_conntrack_tcp_timeout_time_wait" = 1;
    };
  };

  networking.hostName = "erebus";
  nixpkgs.hostPlatform = "x86_64-linux";
}
