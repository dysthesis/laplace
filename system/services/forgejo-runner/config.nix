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
    # Persist DynamicUser's private StateDirectory; mounting its symlink causes EBUSY.
    mnemosyne.dirs = ["/var/lib/private/gitea-runner"];

    services.gitea-actions-runner = {
      inherit (cfg) package;
      instances.${cfg.instanceName} = {
        enable = true;
        name = cfg.instanceName;
        inherit (cfg) url tokenFile labels hostPackages settings;
      };
    };

    # DynamicUser provides the base sandbox; add kernel guards and resource caps.
    # Do not add: MemoryDenyWriteExecute breaks V8; IP filters block Nix fetches;
    # RestrictNamespaces conflicts with Nix; MemoryMax and MemoryHigh break valid CI.
    # earlyoom remains the memory backstop.
    # simplification: CPUQuota and TasksMax are estimates; tune if valid CI is throttled.
    # Unit name assumes a DNS-clean instanceName (no systemd-path escaping).
    systemd.services."gitea-runner-${cfg.instanceName}".serviceConfig = {
      # Keep upstream's token/label registration gate first, then reconcile the
      # address read by the daemon. Embedding cfg.url also restarts on URL changes.
      ExecStartPre = lib.mkAfter [
        (pkgs.writeShellScript "forgejo-runner-reconcile-address-${cfg.instanceName}" ''
          set -eu
          umask 077
          registration="$STATE_DIRECTORY"/${lib.escapeShellArg "${cfg.instanceName}/.runner"}
          address=${lib.escapeShellArg cfg.url}

          if ${lib.getExe pkgs.jq} --exit-status --arg address "$address" '.address == $address' "$registration" >/dev/null; then
            exit 0
          fi

          # Same-directory rename is atomic; mktemp keeps the durable token private.
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

    # Fail evaluation if no nix-prefixed runner label remains.
    assertions = [
      {
        assertion = any (hasPrefix "nix:") cfg.labels;
        message = "laplace.services.forgejo-runner.labels must keep a `nix:`-prefixed label on ${cfg.instanceName}, or `runs-on: nix` workflows stop matching.";
      }
    ];
  };
}
