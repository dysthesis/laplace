{
  config,
  lib,
  ...
}: let
  cfg = config.laplace.services.vikunja.enable;
  inherit (lib) mkEnableOption mkIf;
in {
  options.laplace.services.vikunja.enable =
    mkEnableOption "Vikunja, a self-hosted to-do / task management web app";

  config = mkIf cfg {
    # DynamicUser + StateDirectory=vikunja => the real dir is /var/lib/private/vikunja
    # (with /var/lib/vikunja symlinked to it). Persist the real one; it holds both the
    # sqlite db and uploaded files (files.basepath = /var/lib/vikunja/files).
    mnemosyne.dirs = ["/var/lib/private/vikunja"];

    services.vikunja = {
      enable = true;
      # Bind loopback: the node's own Caddy fronts TLS and proxies to it, so the API
      # never needs to listen past localhost. Default port 3456, default sqlite db.
      address = "127.0.0.1";

      # publicurl defaults: a host fronting a real name overrides these (mkForce) to
      # the public origin. Vikunja bakes publicurl into the frontend's API base, so
      # it must match what the browser hits, not this bare-localhost default.
      frontendScheme = "http";
      frontendHostname = "localhost";
    };
  };
}
