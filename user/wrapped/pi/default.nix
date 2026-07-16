{
  pkgs,
  lib,
  pi-coding-agent,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
  settings = pkgs.writeText "settings.json" (builtins.toJSON {
    defaultProvider = "openai";
    defaultModel = "gpt-5.6-sol";
    defaultThinkingLevel = "max";
    hideThinkingBlock = true;
    theme = "dark";
    enableInstallTelemetry = false;
    enableAnalytics = false;
    compaction.enabled = false;
    packages = [
      "npm:@gotgenes/pi-anthropic-auth"
    ];
  });

  # Gondolin runs pi's tools inside a local micro-VM. Bundled example
  # extension; its @earendil-works/gondolin dep resolves up-tree from pi's
  # own node_modules, so `-e` at the in-store dir needs no npm install.
  # Default VMM backend is QEMU (spawns qemu-system-x86_64 + qemu-img off
  # PATH; kvm accel when /dev/kvm is RW, else TCG).
  gondolin = "${pi-coding-agent}/lib/node_modules/pi-monorepo/examples/extensions/gondolin";
in
  mkWrapper pkgs pi-coding-agent
  # bash
  ''
    # pi treats the agent dir (PI_CODING_AGENT_DIR, default ~/.pi/agent) as a
    # single writable state root: settings.json, its .lock, sessions/, auth.json.
    # So it can't live in the store — seed our managed defaults on first run,
    # then leave the user's copy alone.
    # simplification: seed-once. Editing the Nix settings won't repropagate;
    # `rm ~/.pi/agent/settings.json` to re-seed.
    wrapProgram $out/bin/pi \
      --set PI_TELEMETRY "false" \
      --prefix PATH : "${lib.makeBinPath [pkgs.qemu_kvm]}" \
      --add-flags "-e ${gondolin}" \
      --run 'dir="''${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"; [ -e "$dir/settings.json" ] || install -Dm644 ${settings} "$dir/settings.json"'
  ''
