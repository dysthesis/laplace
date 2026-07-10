{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkAliasOptionModule mkEnableOption mkIf mkOption types;
  cfg = config.laplace.services.headplane;

  # Headplane's StateDirectory (hardcoded "headplane" upstream) resolves here.
  dataDir = "/var/lib/headplane";
  cookieSecret = "${dataDir}/cookie_secret";

  # Headplane refuses to start without a 32-character cookie secret. It is a
  # single-host session-signing key with no need to be shared across machines,
  # so generate it locally on first start and persist it via mnemosyne rather
  # than onboarding this host into sops for one local secret.
  genCookieSecret = pkgs.writeShellScript "headplane-gen-cookie-secret" ''
    set -eu
    if [ ! -s "${cookieSecret}" ]; then
      umask 077
      # 32 printable chars, no trailing newline (tr SIGPIPEs once head exits;
      # the pipeline status is head's 0, so `set -e` without pipefail is fine).
      ${pkgs.coreutils}/bin/tr -dc 'A-Za-z0-9' < /dev/urandom \
        | ${pkgs.coreutils}/bin/head -c 32 > "${cookieSecret}"
    fi
  '';
in {
  imports = [
    (mkAliasOptionModule ["laplace" "services" "headplane" "settings"] ["services" "headplane" "settings"])
  ];

  options.laplace.services.headplane = {
    enable = mkEnableOption "Headplane web UI for Headscale";

    fqdn = mkOption {
      type = types.str;
      default = "headplane.dysthesis.com";
      description = "Public hostname used to reach Headplane (sets server.base_url for OIDC/redirect detection).";
    };

    address = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Address Headplane listens on. Defaults to all interfaces so an edge reverse proxy on another host can reach it.";
    };

    port = mkOption {
      type = types.port;
      default = 3000;
      description = "Port Headplane listens on.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open the Headplane listen port in the host firewall.";
    };
  };

  config = mkIf cfg.enable {
    mnemosyne.dirs = [dataDir];

    services.headplane = {
      enable = true;
      settings.server = {
        host = cfg.address;
        inherit (cfg) port;
        base_url = "https://${cfg.fqdn}";
        # String (not a path literal) so it is not copied to the world-readable
        # store; read at runtime by the headplane process.
        cookie_secret_path = cookieSecret;
      };
    };

    systemd.services.headplane.serviceConfig.ExecStartPre = [genCookieSecret];

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [cfg.port];
  };
}
