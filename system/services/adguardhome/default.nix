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
    # Persist UI-managed filters, rewrites, and accounts.
    mnemosyne.dirs = ["/var/lib/private/AdGuardHome"];

    services.adguardhome = {
      enable = true;
      # Preserve UI changes; declared settings still win during the module merge.
      mutableSettings = true;
      # Keep the UI closed on the LAN; tailscale0 remains trusted.
      openFirewall = false;

      # Must match the port used by node-local Caddy.
      port = 80;

      settings = {
        # Caddy terminates TLS for DoH on the plain HTTP port.
        doh.insecure_enabled = true;

        # Behind node-local Caddy, only loopback should be trusted to supply XFF.
        dns.trusted_proxies = [
          "127.0.0.0/8"
          "::1/128"
        ];

        # Route dysthesis.com directly to Cloudflare to avoid stale negative replies
        # winning parallel upstream races. Nix owns this list; UI edits are temporary.
        dns.upstream_dns = [
          "[/dysthesis.com/]https://dns.cloudflare.com/dns-query"
          "https://dns10.quad9.net/dns-query"
          "https://dns.adguard-dns.com/dns-query"
          "https://dns.cloudflare.com/dns-query"
        ];
      };
    };

    # Open DNS to LAN and tailnet; keep the UI tailnet-only.
    networking.firewall = {
      allowedTCPPorts = [53];
      allowedUDPPorts = [53];
    };
  };
}
