{
  pkgs,
  lib,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;

  # oh-my-pi (omp): a pi-mono fork shipped as a single Bun-compiled executable
  # with the Rust natives embedded — not in nixpkgs. Fetch the prebuilt glibc
  # release and autoPatchelf its interpreter/rpath. NEEDED is glibc-only
  # (libc/ld/pthread/dl/m), so the default buildInputs suffice.
  # dontStrip: the Bun bundle is appended after the ELF; stripping corrupts it.
  omp = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "oh-my-pi";
    version = "17.1.0";
    src = pkgs.fetchurl {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${finalAttrs.version}/omp-linux-x64";
      hash = "sha256-b9cJ7qYm+SUDc3xcaZTWJIP4jdPfJFRELarxmChp0VQ=";
    };
    dontUnpack = true;
    dontStrip = true;
    nativeBuildInputs = [pkgs.autoPatchelfHook];
    buildInputs = [pkgs.stdenv.cc.cc.lib];
    installPhase = ''
      runHook preInstall
      install -Dm755 $src $out/bin/omp
      runHook postInstall
    '';
    meta.mainProgram = "omp";
  });

  # omp reads ~/.omp/agent/config.yml; JSON is a valid YAML subset. Seed only
  # the two prefs that map cleanly off the old pi config (same keys upstream).
  # omp is complete out of the box otherwise — native Anthropic OAuth (the old
  # @gotgenes/pi-anthropic-auth package is obsolete), 40+ providers resolved
  # from env, terminal-detected theme.
  config = pkgs.writeText "config.yml" (builtins.toJSON {
    defaultThinkingLevel = "max";
    hideThinkingBlock = true;
  });
in
  mkWrapper pkgs omp {
    # omp shells out for its git-shaped tools (Bun.spawn ["git", …]).
    binPath = [pkgs.git];
    # Gondolin (pi-mono micro-VM extension) can't be carried over: omp's tools
    # are native Rust in-process, so there is no JS tool execution left for the
    # extension to redirect into a VM, and the compiled binary ships no
    # node_modules for its @earendil-works/gondolin dep to resolve against.
    # omp's own gate is approval mode; it defaults to `yolo` (auto-approve
    # everything), so pin `write` — auto read+write, prompt on exec/bash/network
    # /subagents. Per-session escape hatch: `omp --yolo`.
    addFlags = ["--approval-mode=write"];
    # pi's agent-dir state root (settings/sessions/auth) carries over as omp's.
    # simplification: seed-once. Editing the Nix config won't repropagate;
    # `rm ~/.omp/agent/config.yml` to re-seed.
    run = [''dir="''${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}"; [ -e "$dir/config.yml" ] || install -Dm644 ${config} "$dir/config.yml"''];
  }
