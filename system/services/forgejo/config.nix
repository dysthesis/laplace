{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.services.forgejo;
in {
  config = let
    inherit (config.services) forgejo;
    srv = forgejo.settings.server;
  in
    # From https://wiki.nixos.org/wiki/Forgejo
    mkIf cfg.enable {
      mnemosyne.dirs = [
        forgejo.stateDir
        config.services.postgresql.dataDir
      ];

      networking.firewall.allowedTCPPorts = [
        config.services.forgejo.settings.server.HTTP_PORT
        config.services.forgejo.settings.server.SSH_PORT
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

      services = {
        nginx = {
          virtualHosts.${forgejo.settings.server.DOMAIN} = {
            forceSSL = true;
            enableACME = true;
            extraConfig = ''
              client_max_body_size 512M;
            '';
            locations."/".proxyPass = "http://localhost:${toString srv.HTTP_PORT}";
          };
        };

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
          # Enable support for Git Large File Storage
          lfs.enable = true;

          settings = {
            repository.USE_COMPAT_SSH_URI = false;
            DEFAULT.APP_NAME = "Hephaestus";

            server = {
              DOMAIN = "git.dysthesis.com";
              # You need to specify this to remove the port from URLs in the web UI.
              ROOT_URL = "https://${srv.DOMAIN}/";
              HTTP_PORT = 8080;
              SSH_USER = "git";
              SSH_PORT = lib.head config.services.openssh.ports;
            };

            # You can temporarily allow registration to create an admin user.
            service.DISABLE_REGISTRATION = true;

            # Add support for actions, based on act: https://github.com/nektos/act
            actions = {
              ENABLED = true;
              DEFAULT_ACTIONS_URL = "github";
            };

            # Sending emails is completely optional
            # You can send a test email from the web UI at:
            # Profile Picture > Site Administration > Configuration >  Mailer Configuration
            # mailer = {
            #   ENABLED = true;
            #   SMTP_ADDR = "mail.example.com";
            #   FROM = "noreply@${srv.DOMAIN}";
            #   USER = "noreply@${srv.DOMAIN}";
            # };
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
