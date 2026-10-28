# Forgejo runner client, independent from the server lifecycle and host.
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
in {
  imports = [./config.nix];

  options.laplace.services.forgejo-runner = {
    enable = mkEnableOption "a Forgejo Actions runner (forgejo-runner)";

    instanceName = mkOption {
      type = types.str;
      default = config.networking.hostName;
      defaultText = lib.literalExpression "config.networking.hostName";
      description = ''
        gitea-actions-runner instance name and the systemd unit suffix
        (`gitea-runner-<name>.service`). The persisted `.runner` identity is keyed
        to this, so don't change it casually — a change forces re-registration.
        Assumed to be a DNS-clean label (no systemd-path escaping applied).
      '';
    };

    url = mkOption {
      type = types.str;
      example = "http://localhost:8080";
      description = ''
        Reachable base URL of the Forgejo instance. On startup, the persisted
        `.runner.address` is reconciled to this URL after the upstream registration
        gate. A URL-only change restarts the runner without re-registration,
        retaining its identity and durable token. This supports relocating the
        same Forgejo instance, not moving a registration to a different instance.
      '';
    };

    tokenFile = mkOption {
      type = types.path;
      description = ''
        Path to an EnvironmentFile containing a `TOKEN=` registration token.
        Wire this to a sops secret in the host; the file must remain readable on
        every start. Initial registration, changed token contents, or changed
        labels require a valid registration token. With an unchanged token and
        labels, the persisted `.runner` supplies the durable credentials, so an
        expired registration token does not prevent a URL-only change.
      '';
    };

    labels = mkOption {
      type = types.listOf types.str;
      default = ["nix:host"];
      description = ''
        Runner labels. Must keep a `nix:`-prefixed label (asserted) so
        `runs-on: nix` workflows match. The `:host` suffix selects the host
        backend; a backend swap changes only the suffix, not the `nix` name, so the
        `runs-on:` contract survives it.
      '';
    };

    hostPackages = mkOption {
      type = types.listOf types.package;
      default = with pkgs; [
        bash
        coreutils
        curl
        gawk
        git
        gnused
        nodejs
        wget
        nix
        openssh
        cacert
      ];
      defaultText = lib.literalExpression "module defaults + nix openssh cacert";
      description = ''
        Packages on PATH for host-backend jobs. The upstream module defaults plus
        `nix` (the whole point — jobs run `nix flake check`), `openssh` (git
        remotes over ssh) and `cacert` (TLS to github.com for `uses:` actions).
      '';
    };

    package = mkOption {
      type = types.package;
      default = pkgs.forgejo-runner;
      defaultText = lib.literalExpression "pkgs.forgejo-runner";
      description = ''
        The runner package. `forgejo-runner` (Forgejo's fork), not the
        `gitea-actions-runner` the upstream module defaults to — the fork carries
        the ephemeral-mode / LXC / valid_volumes features.
      '';
    };

    settings = mkOption {
      type = types.attrs;
      default = {};
      description = ''
        Freeform forgejo-runner `config.yaml` (`runner.capacity`, `runner.timeout`,
        `cache.*`, `container.*`, …). Passed verbatim and NOT validated at eval
        time — a typo silently produces an ignored key. Empty = upstream defaults
        (capacity 1, 3h timeout, internal cache server).
      '';
    };
  };
}
