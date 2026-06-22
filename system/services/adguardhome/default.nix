{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.laplace.services.adguardhome.enable;
in {
  options.laplace.services.adguardhome.enable =
    mkEnableOption "Whether or not to enable AdGuard Home";

  config = mkIf cfg {
    # AdGuard's config is managed through the web UI (filters, per-client rules,
    # rewrites). Persist its state dir so impermanence doesn't wipe it - including
    # the admin user created by the first-run wizard.
    mnemosyne.dirs = ["/var/lib/private/AdGuardHome"];

    services.adguardhome = {
      enable = true;
      # mutableSettings keeps web-UI changes (filters, rewrites, the encryption
      # wizard) across rebuilds; the upstream module deep-merges `settings` below
      # over the live config on each start (declarative keys win), so the two
      # coexist.
      mutableSettings = true;
      # Don't open the web UI on every interface. AdGuard still binds 0.0.0.0, but
      # with the port closed in the host firewall only the tailnet can reach it
      # (tailscale0 is a trusted interface); the LAN cannot.
      openFirewall = false;

      # The plain-HTTP UI/DoH port. The module forces
      # http.address = "${host}:${port}" into the merged config, so this MUST
      # match the port the node-local Caddy proxies to (hermes:80) - otherwise the merge
      # resets the UI to the 3000 default and breaks the reverse proxy.
      port = 80;

      settings = {
        # Serve DoH (/dns-query) over the plain HTTP port so node-local Caddy
        # terminates TLS and forwards it. AdGuard Home >= 0.107.74 moved this
        # from tls.allow_unencrypted_doh to doh.insecure_enabled.
        doh.insecure_enabled = true;

        # Behind node-local Caddy, only loopback should be trusted to supply XFF.
        dns.trusted_proxies = [
          "127.0.0.0/8"
          "::1/128"
        ];
      };
    };

    # The resolver port is opened explicitly so LAN/tailnet clients reach DNS on
    # 53; the web UI is deliberately not opened here (tailnet-only, see above).
    networking.firewall = {
      allowedTCPPorts = [53];
      allowedUDPPorts = [53];
    };
  };
}
