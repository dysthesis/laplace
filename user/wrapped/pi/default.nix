{
  pkgs,
  lib,
  pi-coding-agent,
  nodejs_24,
  qemu,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;

  cfg = {
    defaultProvider = "openai";
    defaultModel = "gpt-6-astra";
    defaultThinkingLevel = "max";
    compaction.enabled = false;
    enableInstallTelemetry = false;
    enableAnalytics = false;

    defaultTools = [
      "+codemode"
    ];
  };

  mkCfg = cfg:
    pkgs.writeText "pi-settings.json" (builtins.toJSON cfg);

  settings = mkCfg cfg;

  agents = pkgs.writeText "pi-AGENTS.md" ''
    Always prioritise simple, minimal, semantically tiny solutions that's
    precisely what's needed to solve the given problem with the known
    information, no more, and no less. Do not overfit your solutions. Instead,
    for unknown or uncertain "frontiers" of the design, make it _extensible_,
    defining a clear, coherent interface to extend it in the future if/when
    enough information becomes known, or designing such a solution becomes
    unavoidable.
  '';
  piSrc = pkgs.fetchFromGitHub {
    owner = "earendil-works";
    repo = "pi";
    rev = "v${pi-coding-agent.version}";
    hash = "sha256-ukN//DNSnCr9gZHKSzexAGEZu95eMzTGJLjLc5B+Hwo=";
  };
in
  mkWrapper pkgs pi-coding-agent {
    binPath = [
      nodejs_24
      qemu
    ];

    run = [
      ''
        state="''${XDG_STATE_HOME:-$HOME/.local/state}/pi"
        agent="$state/agent"
        sessions="$state/sessions"
        gondolin="$agent/extensions/gondolin"

        mkdir -p "$agent" "$sessions"

        rm -f "$agent/settings.json"
        install -m 0644 ${settings} "$agent/settings.json"

        rm -f "$agent/AGENTS.md"
        ln -s ${agents} "$agent/AGENTS.md"

        # Install the Gondolin extension once.
        if [ ! -d "$gondolin/node_modules/@earendil-works/gondolin" ]; then
          rm -rf "$gondolin"
          mkdir -p "$gondolin"

          cp -R \
            ${piSrc}/packages/coding-agent/examples/extensions/gondolin/. \
            "$gondolin/"

          chmod -R u+w "$gondolin"

          (
            cd "$gondolin"
            npm install --ignore-scripts
          )
        fi

        export PI_CODING_AGENT_DIR="$agent"
        export PI_CODING_AGENT_SESSION_DIR="$sessions"
      ''
    ];
  }
