# PHP and uWSGI package definitions from gdamjan/wallabag-service.
# Caddy cannot proxy uWSGI, so run a native service on loopback HTTP.
# Build only PHP and uWSGI; omit the upstream portableService wrapper.
{
  pkgs,
  wallabag ? pkgs.wallabag,
  # wallabag 2.6.x (Symfony 4.4) targets PHP <= 8.3; pkgs.php is 8.4. The package
  # copies files only (no build-time PHP run), so a version mismatch would only
  # bite at boot; pin 8.3 to stay in Wallabag's supported range.
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
    # Keep nixpkgs' default extension set and
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
