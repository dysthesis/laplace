# PHP and uWSGI package definitions from gdamjan/wallabag-service.
#
# Upstream wraps these in `pkgs.portableService` and serves the uwsgi protocol
# on a unix socket (/run/wallabag.sock) for nginx to proxy. This repo fronts
# every service with Caddy, which speaks HTTP/FastCGI but *not* the uwsgi
# protocol, so ../default.nix points uwsgi at a loopback HTTP socket instead and
# runs it as a native unit. Here we only build the two artefacts that
# integration needs; the portableService wrapper and its symlinks are dropped.
{
  pkgs,
  wallabag ? pkgs.wallabag,
  # wallabag 2.6.x (Symfony 4.4) targets PHP <= 8.3; pkgs.php is 8.4. The package
  # copies files only (no build-time PHP run), so a version mismatch would only
  # bite at boot — pin 8.3 to stay in wallabag's supported range.
  php ? pkgs.php83,
  uwsgi ? pkgs.uwsgi,
}: let
  phpWithModules =
    (php.override {
      embedSupport = true;
      cliSupport = true;
      cgiSupport = false;
      fpmSupport = false;
      phpdbgSupport = false;
      systemdSupport = false;
      apxs2Support = false;
    })
    # Keep nixpkgs' default extension set (filter, json, hash, fileinfo, …) and
    # add wallabag's extras; returning only an explicit list drops the defaults
    # and e.g. filter_var() goes undefined.
    .withExtensions ({
      all,
      enabled,
      ...
    }:
      enabled
      ++ (with all; [
        pdo
        pdo_pgsql
        session
        ctype
        dom
        simplexml
        gd
        mbstring
        tidy
        iconv
        curl
        gettext
        tokenizer
        bcmath
        intl
        opcache
      ]));

  # uwsgi rebuilds its own php-embed from this `php` (same version), and loads
  # the extensions above at runtime via phpWithModules' generated php.ini, which
  # ../files/uwsgi.wallabag.ini.in points `php-ini` at.
  uwsgiWithPhp = uwsgi.override {
    withPAM = false;
    plugins = ["php"];
    php = phpWithModules;
  };
in {
  inherit wallabag;
  php = phpWithModules;
  uwsgi = uwsgiWithPhp;
}
