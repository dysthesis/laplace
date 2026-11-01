{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf any hasPrefix;
  cfg = config.laplace.services.forgejo-runner;
in {
  config = mkIf cfg.enable {
    # Persist the private DynamicUser StateDirectory. A mount over its symlink causes EBUSY.
    mnemosyne.dirs = ["/var/lib/private/gitea-runner"];

    services.gitea-actions-runner = {
      inherit (cfg) package;
      instances.${cfg.instanceName} = {
        enable = true;
        name = cfg.instanceName;
        inherit (cfg) url tokenFile labels hostPackages settings;
      };
    };

    # DynamicUser gives the base sandbox.
    # MemoryDenyWriteExecute breaks V8. IP filters block Nix fetches.
    # RestrictNamespaces conflicts with Nix.
    # MemoryMax and MemoryHigh can stop correct CI jobs. earlyoom limits memory pressure.
    # CPUQuota and TasksMax are estimates. Adjust them if they restrict correct CI jobs.
    # Use a DNS-safe instanceName because the unit name has no systemd path escaping.
    systemd.services."gitea-runner-${cfg.instanceName}".serviceConfig = {
      # Reconcile the daemon address after the token and label checks.
      # The embedded cfg.url restarts the daemon when the URL changes.
      ExecStartPre = lib.mkAfter [
        (pkgs.writeShellScript "forgejo-runner-reconcile-address-${cfg.instanceName}" ''
          set -eu
          umask 077
          registration="$STATE_DIRECTORY"/${lib.escapeShellArg "${cfg.instanceName}/.runner"}
          address=${lib.escapeShellArg cfg.url}

          if ${lib.getExe pkgs.jq} --exit-status --arg address "$address" '.address == $address' "$registration" >/dev/null; then
            exit 0
          fi

          # A rename in the same directory is atomic. mktemp keeps the registration token private.
          temporary="$(${pkgs.coreutils}/bin/mktemp "$registration.XXXXXX")"
          trap '${pkgs.coreutils}/bin/rm -f -- "$temporary"' EXIT
          ${lib.getExe pkgs.jq} --arg address "$address" '.address = $address' "$registration" >"$temporary"
          ${pkgs.coreutils}/bin/mv -f -- "$temporary" "$registration"
        '')
      ];

      CPUQuota = "300%";
      TasksMax = 4096;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      ProtectClock = true;
      ProtectHostname = true;
      PrivateDevices = true;
      LockPersonality = true;
      RestrictRealtime = true;
      # Keep AF_NETLINK for address and route lookups.
      RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK"];
    };

    assertions = [
      {
        assertion = any (hasPrefix "nix:") cfg.labels;
        message = "laplace.services.forgejo-runner.labels must keep a `nix:`-prefixed label on ${cfg.instanceName}, or `runs-on: nix` workflows stop matching.";
      }
    ];
  };
}
