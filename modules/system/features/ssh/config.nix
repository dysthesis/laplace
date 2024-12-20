{
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    mkIf
    ;

  cfg = config.laplace.features.ssh.enable;
in {
  config = mkIf cfg {
    services.openssh = {
      enable = lib.mkDefault true;
      settings = {
        PermitRootLogin = lib.mkForce "no";
        UseDns = false;
        X11Forwarding = false;
        PasswordAuthentication = lib.mkForce false;
        KbdInteractiveAuthentication = false;
      };
      openFirewall = true;
      ports = [22];
      # hostKeys = [
      #   {
      #     bits = 4096;
      #     path = "/etc/ssh/ssh_host_rsa_key";
      #     type = "rsa";
      #   }
      #   {
      #     path = "/etc/ssh/ssh_host_ed25519_key";
      #     type = "ed25519";
      #   }
      # ];
    };

    # system.activationScripts.generateHostSSHKeys =
    #   fold
    #   (curr: acc:
    #     /*
    #     sh
    #     */
    #     ''
    #       ${acc}
    #       ${pkgs.openssh}/bin/ssh-keygen -t ${curr.type} -N "" -f ${curr.path}
    #     '')
    #   /*
    #   sh
    #   */
    #   ''
    #     mkdir -p /etc/ssh
    #   ''
    #   config.services.openssh.hostKeys;
  };
}
