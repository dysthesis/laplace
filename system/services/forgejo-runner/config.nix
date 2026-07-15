{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf any hasPrefix;
  cfg = config.laplace.services.forgejo-runner;
in {
  config = mkIf cfg.enable {
    # Runner registration (.runner) + label/token hashes. The runner is a
    # DynamicUser, so systemd keeps real StateDirectory= contents in
    # /var/lib/private/gitea-runner and leaves /var/lib/gitea-runner a symlink to
    # it — persist the private path across the tmpfs root (the symlink would save
    # nothing, and bind-mounting the public path makes systemd fail StateDirectory
    # setup with EBUSY migrating a mountpoint into /var/lib/private). Without this
    # the runner re-registers every boot and burns a fresh token each time.
    mnemosyne.dirs = ["/var/lib/private/gitea-runner"];

    services.gitea-actions-runner = {
      inherit (cfg) package;
      instances.${cfg.instanceName} = {
        enable = true;
        name = cfg.instanceName;
        inherit (cfg) url tokenFile labels hostPackages settings;
      };
    };

    # Hardening the upstream module does not apply. DynamicUser already implies
    # ProtectSystem=strict, ProtectHome=read-only, NoNewPrivileges, RestrictSUIDSGID
    # and RemoveIPC; add the kernel-protection set it does NOT imply, plus resource
    # pressure caps (forgejo-runner ships none — a runaway job otherwise eats
    # the whole ~6 GiB runner VM).
    #
    # Deliberately NOT set, each for a concrete reason (do not "helpfully" re-add):
    #   MemoryDenyWriteExecute  → breaks node's V8 JIT (nodejs is on PATH for JS actions)
    #   IPAddressAllow/Deny     → breaks `nix flake check` fetching arbitrary inputs
    #   RestrictNamespaces      → nix/namespace friction; revisit once CI confirms safe
    #   MemoryMax (hard)        → risks killing a legit nix eval/build at a guessed line;
    #                             earlyoom (proxmox profile) is the real OOM backstop
    #   MemoryHigh              → live 3G/4G thresholds forced valid CI into swap;
    #                             earlyoom remains the measured backstop
    #
    # simplification: CPUQuota/TasksMax are conservative figures sized to a 6 GiB
    # ceiling, not measured. Tune (or drop) if legit CI is throttled.
    # Unit name assumes a DNS-clean instanceName (no systemd-path escaping).
    systemd.services."gitea-runner-${cfg.instanceName}".serviceConfig = {
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
      # AF_NETLINK kept (getaddrinfo / route queries); only raw-packet families dropped.
      RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK"];
    };

    # The whole design leans on a `nix:`-prefixed label surviving any backend swap;
    # fail at eval, not silently at deploy, if it is ever dropped.
    assertions = [
      {
        assertion = any (hasPrefix "nix:") cfg.labels;
        message = "laplace.services.forgejo-runner.labels must keep a `nix:`-prefixed label on ${cfg.instanceName}, or `runs-on: nix` workflows stop matching.";
      }
    ];
  };
}
