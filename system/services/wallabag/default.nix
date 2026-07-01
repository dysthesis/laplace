{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.laplace.services.wallabag;
  inherit (lib) mkEnableOption mkIf mkOption types;

  # PHP (+ wallabag's extensions) and uwsgi (+ php plugin), vendored from
  # gdamjan/wallabag-service. See ./build.nix for the upstream divergence.
  build = import ./build.nix {inherit pkgs;};

  dataDir = "/var/lib/wallabag";
  user = "wallabag";

  uwsgiIni = pkgs.replaceVars ./files/uwsgi.wallabag.ini.in {
    inherit dataDir;
    port = toString cfg.port;
    inherit (cfg) timezone;
    mimeTypes = "${pkgs.mailcap}/etc/mime.types";
    siteRoot = "${dataDir}/web";
    phpIni = "${build.php}/lib/php.ini";
  };

  # Front controller. Caddy terminates TLS and dials wallabag on loopback;
  # without trusting that proxy Symfony reads the request as plain http and emits
  # http redirects + non-Secure cookies, breaking login over the https-only
  # tailnet. Symfony 4 removed `framework.trusted_proxies`, so it must be set on
  # the Request here. Replaces the package's web/app.php (see preStart).
  appPhp = pkgs.writeText "wallabag-app.php" ''
    <?php

    use Symfony\Component\HttpFoundation\Request;

    require __DIR__.'/../vendor/autoload.php';

    Request::setTrustedProxies(
        ['127.0.0.1', '::1'],
        Request::HEADER_X_FORWARDED_FOR
        | Request::HEADER_X_FORWARDED_HOST
        | Request::HEADER_X_FORWARDED_PORT
        | Request::HEADER_X_FORWARDED_PROTO
    );

    $kernel = new AppKernel('prod', false);
    $request = Request::createFromGlobals();
    $response = $kernel->handle($request);
    $response->send();
    $kernel->terminate($request, $response);
  '';

  # Everything wallabag's parameters.yml needs bar `secret`, which is appended at
  # runtime from the sops credential so it never lands in the Nix store. The
  # package's config.yml imports parameters.yml *relatively*, so this copy in
  # $WALLABAG_DATA naturally overrides the package's defaults.
  paramsHead = pkgs.writeText "wallabag-parameters-head.yml" ''
    parameters:
        database_driver: pdo_pgsql
        database_host: /run/postgresql
        database_port: ~
        database_name: ${cfg.database.name}
        database_user: ${cfg.database.user}
        database_password: ~
        database_path: null
        database_table_prefix: wallabag_
        database_socket: null
        database_charset: utf8
        domain_name: https://${cfg.domain}
        server_name: "${cfg.domain}"
        mailer_dsn: ${cfg.mailerDsn}
        locale: en
        twofactor_sender: no-reply@${cfg.domain}
        fosuser_registration: false
        fosuser_confirmation: false
        fos_oauth_server_access_token_lifetime: 3600
        fos_oauth_server_refresh_token_lifetime: 1209600
        from_email: no-reply@${cfg.domain}
        rss_limit: 50
        rabbitmq_host: localhost
        rabbitmq_port: 5672
        rabbitmq_user: guest
        rabbitmq_password: guest
        rabbitmq_prefetch_count: 10
        redis_scheme: tcp
        redis_host: localhost
        redis_port: 6379
        redis_path: null
        redis_password: null
        sentry_dsn: ~
  '';

  preStart = pkgs.writeShellScript "wallabag-pre-start" ''
    set -euo pipefail
    export PATH=${lib.makeBinPath [pkgs.coreutils build.php]}:$PATH
    export WALLABAG_DATA=${dataDir}
    src=${build.wallabag}

    # wallabag reads its config from $WALLABAG_DATA and resolves %kernel.project_dir%
    # there too, so the data dir must mirror the package as a project root. Rebuild
    # it as a symlink farm each boot (cheap; repoints automatically on upgrade);
    # only app/config (our parameters.yml), web/ (our front controller), var/ and
    # data/ are real and writable.
    # simplification: symlink farm keyed on the package store path; the package
    # can't write outside var//data/ (image download to web/assets is off).
    # app/ and web/ are pure symlink-farm + our two files, so wipe and rebuild
    # them each boot (self-heals a stale symlink-vs-dir from an earlier layout);
    # real state (var/, data/, markers) lives outside them.
    rm -rf ${dataDir}/app ${dataDir}/web
    mkdir -p ${dataDir}/app/config ${dataDir}/web ${dataDir}/var ${dataDir}/data/db
    for e in "$src"/*; do
      n=$(basename "$e")
      case "$n" in app|var|data|web) continue ;; esac
      ln -sfn "$e" ${dataDir}/"$n"
    done
    for e in "$src"/app/*; do
      n=$(basename "$e")
      [ "$n" = config ] && continue
      ln -sfn "$e" ${dataDir}/app/"$n"
    done
    for e in "$src"/app/config/*; do
      n=$(basename "$e")
      [ "$n" = parameters.yml ] && continue
      ln -sfn "$e" ${dataDir}/app/config/"$n"
    done
    for e in "$src"/web/*; do
      n=$(basename "$e")
      [ "$n" = app.php ] && continue
      ln -sfn "$e" ${dataDir}/web/"$n"
    done
    cp -f ${appPhp} ${dataDir}/web/app.php

    # parameters.yml = static head + the sops secret (rendered every boot).
    { cat ${paramsHead}; printf '    secret: %s\n' "$(cat "$CREDENTIALS_DIRECTORY/secret")"; } \
      > ${dataDir}/app/config/parameters.yml
    chmod 600 ${dataDir}/app/config/parameters.yml

    # Drop the stale Symfony cache when the package changes.
    stamp=${dataDir}/.wallabag-pkg
    if [ "$(cat "$stamp" 2>/dev/null || true)" != "$src" ]; then
      rm -rf ${dataDir}/var/cache
      printf '%s\n' "$src" > "$stamp"
    fi

    console="$src"/bin/console
    if [ ! -e ${dataDir}/.wallabag-installed ]; then
      # First boot: build the schema + run migrations.
      php "$console" wallabag:install --no-interaction --env=prod
      touch ${dataDir}/.wallabag-installed
    else
      php "$console" doctrine:migrations:migrate --no-interaction --env=prod
    fi

    # wallabag:install --no-interaction does NOT create the admin, so do it
    # explicitly (login: wallabag / password: wallabag — CHANGE IT after first
    # login). simplification: that password is wallabag's well-known public
    # default, not a secret, so it's fine in the unit; it must be changed.
    if [ ! -e ${dataDir}/.wallabag-admin ]; then
      if php "$console" fos:user:create --super-admin --env=prod \
           ${cfg.adminUser} ${cfg.adminEmail} wallabag; then
        touch ${dataDir}/.wallabag-admin
      fi
    fi

    php "$console" cache:clear --env=prod
  '';
in {
  options.laplace.services.wallabag = {
    enable = mkEnableOption "wallabag, a self-hosted read-it-later web app (uwsgi/php)";

    domain = mkOption {
      type = types.str;
      example = "wallabag.example.com";
      description = "Public origin the browser hits; baked into wallabag's links and cookie scope. The node-local Caddy terminates TLS and proxies to {option}`port`.";
    };

    port = mkOption {
      type = types.port;
      default = 8108;
      description = "Loopback HTTP port uwsgi serves; the node-local Caddy proxies to this.";
    };

    timezone = mkOption {
      type = types.str;
      default = "UTC";
      description = "PHP date.timezone for the wallabag workers.";
    };

    mailerDsn = mkOption {
      type = types.str;
      default = "smtp://127.0.0.1";
      description = "Symfony mailer DSN. Unused unless registration / 2FA email is enabled.";
    };

    adminUser = mkOption {
      type = types.str;
      default = "wallabag";
      description = "Username of the bootstrap super-admin created on first boot. Its password is the well-known default `wallabag` — change it after first login.";
    };

    adminEmail = mkOption {
      type = types.str;
      default = "wallabag@localhost";
      description = "Email address for the bootstrap super-admin.";
    };

    database = {
      name = mkOption {
        type = types.str;
        default = "wallabag";
        description = "Local PostgreSQL database name (owned by {option}`database.user`).";
      };
      user = mkOption {
        type = types.str;
        default = "wallabag";
        description = "PostgreSQL role; must equal the service's Unix user for peer auth.";
      };
    };
  };

  config = mkIf cfg.enable {
    mnemosyne.dirs = ["${dataDir}" "/var/lib/postgresql"];

    # Symfony "secret" for token signing. Add `wallabag_secret` to the host's
    # sops file (e.g. `openssl rand -hex 32`).
    sops.secrets.wallabag_secret = {};

    # Static user (not DynamicUser): the persisted state dir is owned across
    # reboots by a stable uid, and Postgres peer auth maps this Unix user to the
    # matching role.
    users.users.${user} = {
      isSystemUser = true;
      group = user;
      home = dataDir;
    };
    users.groups.${user} = {};

    services.postgresql = {
      enable = true;
      ensureDatabases = [cfg.database.name];
      ensureUsers = [
        {
          name = cfg.database.user;
          ensureDBOwnership = true;
        }
      ];
    };

    systemd.services.wallabag = {
      description = "wallabag read-it-later (uwsgi/php)";
      after = ["network.target" "postgresql.service"];
      requires = ["postgresql.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "notify";
        User = user;
        Group = user;
        StateDirectory = "wallabag";
        # The state dir, which systemd creates before ExecStartPre. Not web/ —
        # that is built by ExecStartPre, but systemd chdirs here first. uwsgi
        # chdirs to the site-root itself (ini `chdir`).
        WorkingDirectory = dataDir;
        Environment = ["WALLABAG_DATA=${dataDir}"];
        LoadCredential = ["secret:${config.sops.secrets.wallabag_secret.path}"];
        ExecStartPre = "${preStart}";
        ExecStart = "${build.uwsgi}/bin/uwsgi --ini ${uwsgiIni}";
        TimeoutStartSec = "300";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
