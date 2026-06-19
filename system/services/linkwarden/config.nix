{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.services.linkwarden;

  # storageLocation resolves here (StateDirectory = "linkwarden" upstream).
  dataDir = "/var/lib/linkwarden";
  nextauthSecret = "${dataDir}/nextauth_secret";

  # Linkwarden refuses to start without a NextAuth secret. It is a single-host
  # session-signing key with no need to be shared across machines, so generate
  # it locally on first start and persist it via mnemosyne rather than
  # onboarding this host into sops for one local secret (mirrors headplane).
  genNextauthSecret = pkgs.writeShellScript "linkwarden-gen-nextauth-secret" ''
    set -eu
    if [ ! -s "${nextauthSecret}" ]; then
      umask 077
      # 48 printable chars, no trailing newline (tr SIGPIPEs once head exits;
      # the pipeline status is head's 0, so `set -e` without pipefail is fine).
      ${pkgs.coreutils}/bin/tr -dc 'A-Za-z0-9' < /dev/urandom \
        | ${pkgs.coreutils}/bin/head -c 48 > "${nextauthSecret}"
    fi
  '';
in {
  config = mkIf cfg.enable {
    # Tailnet-only: bind to the tailnet but never add the port to the firewall.
    # laplace.services.tailscale marks tailscale0 as a trusted interface, so
    # tailnet peers reach `host:port` while the default firewall blocks LAN and
    # public traffic.
    assertions = [
      {
        assertion = config.laplace.services.tailscale.enable;
        message = "laplace.services.linkwarden binds to the tailnet; enable laplace.services.tailscale on this host.";
      }
    ];

    # Persist bookmarks/archives and the Postgres cluster across ephemeral-root
    # wipes. The cache (/var/cache/linkwarden, also CHROME_CONFIG_HOME) is left
    # unpersisted on purpose; the headless-Chrome cache rebuilds on demand.
    mnemosyne.dirs = [
      dataDir
      config.services.postgresql.dataDir
    ];

    services.linkwarden = {
      enable = true;
      inherit (cfg) host port enableRegistration;
      storageLocation = dataDir;
      # Exposure is gated by the tailscale-trusted interface, not an open port.
      openFirewall = false;
      # Read the locally-generated secret at startup; a string (not a path
      # literal) so it is never copied to the world-readable store.
      secretFiles.NEXTAUTH_SECRET = nextauthSecret;
      # database.createLocally defaults on: a local Postgres cluster reached over
      # the /run/postgresql unix socket (peer auth, so no password is needed).
    };

    # The worker unit reads the same secret but starts after linkwarden.service,
    # so generating it here covers both.
    systemd.services.linkwarden.serviceConfig.ExecStartPre = [genNextauthSecret];
  };
}
