{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.services.forgejo;

  # Cheap, deploy-safe sandbox for the two module oneshots that ship with none
  # (forgejo-secrets generates SECRET_KEY et al.; forgejo-dump writes the backup
  # archive). ProtectSystem="full" (not "strict") keeps /var and /run writable, so
  # neither the customDir secret write nor the Postgres-socket dump needs per-unit
  # ReadWritePaths bookkeeping — while /usr, /boot and /etc still go read-only.
  hardenOneshot = {
    ProtectSystem = "full";
    ProtectHome = true;
    PrivateTmp = true;
    NoNewPrivileges = true;
    CapabilityBoundingSet = "";
  };
in {
  config = let
    inherit (config.services) forgejo;
    srv = forgejo.settings.server;
  in
    # No node-local reverse proxy or ACME here: TLS terminates at the edge on
    # portunus's Caddy, which gates git.dysthesis.com behind Anubis and proxies
    # to this host's raw HTTP_PORT over the VLAN40->VLAN70 pinhole. Forgejo
    # serves plain HTTP on :8080, and the hephaestus firewall scopes that port
    # to portunus + the talos runner only. SSH_PORT is the system openssh port,
    # already scoped to VLAN20 by the proxmox profile.
    mkIf cfg.enable {
      mnemosyne.dirs = [
        forgejo.stateDir
        config.services.postgresql.dataDir
      ];

      systemd.tmpfiles.rules = [
        "d '${forgejo.stateDir}' 0750 ${forgejo.user} ${forgejo.group} - -"
        "d '${forgejo.stateDir}/.ssh' 0700 ${forgejo.user} ${forgejo.group} - -"
        "d '${forgejo.stateDir}/custom' 0750 ${forgejo.user} ${forgejo.group} - -"
        "d '${forgejo.stateDir}/dump' 0750 ${forgejo.user} ${forgejo.group} - -"
        "d '${forgejo.stateDir}/data' 0750 ${forgejo.user} ${forgejo.group} - -"
        "d '${forgejo.stateDir}/data/tmp' 0750 ${forgejo.user} ${forgejo.group} - -"
        "d '${forgejo.stateDir}/log' 0750 ${forgejo.user} ${forgejo.group} - -"
        "d '${forgejo.stateDir}/repositories' 0750 ${forgejo.user} ${forgejo.group} - -"
        "Z '${forgejo.stateDir}/.ssh' - ${forgejo.user} ${forgejo.group} - -"
        "Z '${forgejo.stateDir}/custom' - ${forgejo.user} ${forgejo.group} - -"
        "Z '${forgejo.stateDir}/dump' - ${forgejo.user} ${forgejo.group} - -"
        "Z '${forgejo.stateDir}/data' - ${forgejo.user} ${forgejo.group} - -"
        "Z '${forgejo.stateDir}/log' - ${forgejo.user} ${forgejo.group} - -"
        "Z '${forgejo.stateDir}/repositories' - ${forgejo.user} ${forgejo.group} - -"
      ];

      # Backfill sandboxing on the module's two unsandboxed oneshots (see the
      # hardenOneshot note above). forgejo-secrets always exists; forgejo-dump only
      # when dump.enable — guard it so toggling dump off never leaves a phantom unit.
      systemd.services.forgejo-secrets.serviceConfig = hardenOneshot;
      systemd.services.forgejo-dump.serviceConfig =
        mkIf forgejo.dump.enable hardenOneshot;

      services = {
        forgejo = {
          enable = true;
          inherit (cfg) stateDir;
          user = "git";
          group = "git";
          database = {
            type = "postgres";
            user = "git";
            name = "git";
          };
          lfs.enable = true;

          # Logical dump (repos + DB + config) alongside the whole-VM PBS backups,
          # for Postgres-major-bump / logical-restore portability. Writes into the
          # already persisted + PBS-covered stateDir/dump; tar.zst + short retention
          # (PBS is the authoritative backup, this is insurance).
          # simplification: age=3d is a conservative guess — size it to the repo
          # corpus (du -sh stateDir/{repositories,data/lfs}); daily full-repo
          # archives can balloon the 128G disk. Upgrade path for intra-day RPO:
          # WAL archiving / pgBackRest (PITR).
          dump = {
            enable = true;
            type = "tar.zst";
            age = "3d";
          };

          settings = {
            repository = {
              USE_COMPAT_SSH_URI = false;
              DEFAULT_PRIVATE = "private";
            };
            DEFAULT.APP_NAME = "Hephaestus";

            server = {
              DOMAIN = "git.dysthesis.com";
              ROOT_URL = "https://${srv.DOMAIN}/";
              HTTP_PORT = 8080;
              SSH_USER = "git";
              SSH_PORT = lib.head config.services.openssh.ports;
            };

            # Registration stays closed; anonymous viewing of *public* repos is
            # left ON (REQUIRE_SIGNIN_VIEW unset) so a repo can be shared by link.
            service = {
              DISABLE_REGISTRATION = true;
              # Don't leak the admin's email in commit-author / API views.
              DEFAULT_KEEP_EMAIL_PRIVATE = true;
            };

            # TLS terminates at portunus (10.0.40.2); Forgejo speaks plain HTTP on
            # :8080. Requests traverse TWO proxies on portunus (Caddy, then the
            # Anubis gate), but Anubis flattens X-Forwarded-For and strips its
            # own loopback hop before proxying on, so exactly ONE proxy hop is
            # visible here and XFF arrives as just "<client>".
            # REVERSE_PROXY_LIMIT stays at its default (1 = exactly one proxy hop).
            security = {
              REVERSE_PROXY_TRUSTED_PROXIES = "10.0.40.2/32";
              # Local-account password policy. PASSWORD_COMPLEXITY is a comma-joined
              # string, never a Nix list (the ini generator aborts on a list value).
              MIN_PASSWORD_LENGTH = 12;
              PASSWORD_COMPLEXITY = "lower,upper,digit,spec";
              PASSWORD_HASH_ALGO = "argon2"; # memory-hard; applies to newly-set passwords
              LOGIN_REMEMBER_DAYS = 7;
              # Reject API tokens passed in the URL query string (they leak via
              # access logs and Referer headers).
              DISABLE_QUERY_AUTH_TOKEN = true;
              GLOBAL_TWO_FACTOR_REQUIREMENT = "admin";
            };

            # The NixOS module declares COOKIE_SECURE as a typed leaf defaulting to
            # false, so it is ALWAYS written to app.ini and pre-empts Forgejo's own
            # https-ROOT_URL auto-detect. Force it true — the edge is HTTPS-only.
            session.COOKIE_SECURE = true;

            other.SHOW_FOOTER_VERSION = false;

            actions = {
              ENABLED = true;
              DEFAULT_ACTIONS_URL = "github";
            };
          };
        };
      };

      users = {
        users.git = {
          home = config.services.forgejo.stateDir;
          useDefaultShell = true;
          group = "git";
          isSystemUser = true;
        };

        groups.git = {};
      };
    };
}
