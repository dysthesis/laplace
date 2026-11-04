{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.laplace.services.miniflux.enable;
  inherit
    (lib)
    mkForce
    getExe
    mkIf
    ;
in {
  options.laplace.services.miniflux.enable =
    lib.mkEnableOption "Whether or not to enable the Miniflux RSS feed reader";

  config = mkIf cfg {
    mnemosyne.dirs = [
      "/var/lib/private/miniflux"
      "/var/lib/postgresql"
    ];

    sops.secrets.miniflux_admin = {};

    services.miniflux = {
      enable = true;
      config = {
        LISTEN_ADDR = lib.mkDefault "127.0.0.1:8087";
        BASE_URL = lib.mkDefault "http://localhost:8087";
        CLEANUP_FREQUENCY_HOURS = "168";
      };
      adminCredentialsFile = config.sops.secrets.miniflux_admin.path;
    };

    security.apparmor.policies."bin.miniflux".profile = mkForce ''
      abi <abi/4.0>,
      include <tunables/global>

      profile ${getExe config.services.miniflux.package} flags=(attach_disconnected) {
        include <abstractions/base>
        include <abstractions/nameservice>
        include <abstractions/ssl_certs>
        include <abstractions/golang>
        include "${pkgs.apparmorRulesFromClosure {name = "miniflux";} config.services.miniflux.package}"
        ${getExe config.services.miniflux.package} r,
        /run/miniflux/** rw,

        # PostgreSQL socket mediation can report disconnected paths.
        /run/postgresql/ r,
        /run/postgresql/.s.PGSQL.5432 rw,
        /run/postgresql/.s.PGSQL.5432.lock r,

        include if exists <local/bin.miniflux>
      }
    '';
  };
}
