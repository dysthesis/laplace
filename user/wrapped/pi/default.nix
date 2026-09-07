{
  callPackage,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
  minimalTheme = callPackage ./theme.nix {inherit pkgs;};

  # Package the prebuilt glibc OMP binary with autoPatchelf.
  # Do not strip: Bun appends its bundle after the ELF.
  omp = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "oh-my-pi";
    version = "18.1.13";
    src = pkgs.fetchurl {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${finalAttrs.version}/omp-linux-x64";
      hash = "sha256-O+WjCMyR5va7oUgXX75lHTWD/20yriIcuTHcCKZOHzk=";
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

  # Seed only preferences not covered by OMP defaults.
  config = pkgs.writeText "config.yml" (builtins.toJSON {
    defaultThinkingLevel = "max";
    hideThinkingBlock = true;
    theme.dark = "minimal";
  });
in
  mkWrapper pkgs omp {
    # OMP shells out for Git-shaped tools through Bun.spawn.
    binPath = [pkgs.git];
    # Pin write mode: approve file access, prompt for execution and network access.
    # Use omp --yolo only per session.
    addFlags = ["--approval-mode=write"];
    # simplification: seed user-editable files once; delete one to apply later Nix changes.
    run = [
      ''
        dir="''${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}"
        [ -e "$dir/config.yml" ] \
          || install -Dm644 ${config} "$dir/config.yml"

        [ -e "$dir/themes/minimal.json" ] \
          || install -Dm644 ${minimalTheme} "$dir/themes/minimal.json"

        [ -e "$dir/agents/explorer.md" ] \
          || install -Dm644 ${./agents/explorer.md} "$dir/agents/explorer.md"
      ''
    ];
  }
