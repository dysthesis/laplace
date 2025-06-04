{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  cfg = config.laplace.network.vpn;
in
{
  config = mkIf cfg.enable {
    sops.secrets.mullvad = { };
    services.mullvad-vpn = {
      enable = true;
      package = pkgs.mullvad-vpn;
    };
    # systemd.services."mullvad-daemon" = {
    #   postStart = let
    #     mullvad = "${lib.getExe config.services.mullvad-vpn.package}";
    #   in
    #     /*
    #     sh
    #     */
    #     ''
    #       #!/bin/sh
    #       while ! ${mullvad} status &>/dev/null; do sleep 1; done
    #       account="$(<"${config.sops.secrets.mullvad.path}")"
    #       current_account="$(${mullvad} account get | grep "account:" | sed 's/.* //')"
    #       if [[ "$current_account" != "$account" ]]; then
    #         ${mullvad} account login "$account"
    #       fi
    #
    #       ${mullvad} auto-connect set on
    #       ${mullvad} dns set default \
    #         --block-ads \
    #         --block-malware \
    #         --block-trackers
    #
    #       ${mullvad} connect
    #     '';
    # };
  };
}
