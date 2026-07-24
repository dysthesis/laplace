# Pin benchmark tools; inherit Nix itself to build tested artefacts.
pkgs: let
  inherit (pkgs) lib;
  # rich powers the progress bars + result tables in pty-probe.py / stats.py.
  pythonEnv = pkgs.python3.withPackages (ps: [ps.rich]);
  tools = lib.makeBinPath (with pkgs; [
    hyperfine
    strace
    pythonEnv
    jq
    util-linux # taskset
    coreutils
    gnused
    gnugrep
    findutils
    git
    fish # fallback / unwrapped ablation runner
    bash
  ]);
in
  pkgs.stdenvNoCC.mkDerivation {
    pname = "laplace-shell-bench";
    version = "0.1.0";
    src = ./.;
    nativeBuildInputs = [pkgs.makeWrapper];
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/bench $out/bin
      for f in shell-bench.sh lib.sh pty-probe.py stats.py ui.py README.md; do
        [ -e "$src/$f" ] && cp "$src/$f" "$out/share/bench/$f"
      done
      chmod +x $out/share/bench/shell-bench.sh
      makeWrapper $out/share/bench/shell-bench.sh $out/bin/shell-bench \
        --set BENCH_LIB $out/share/bench \
        --prefix PATH : ${tools}
      runHook postInstall
    '';
    meta = {
      description = "Reproducible startup-latency benchmark for this flake's shells";
      mainProgram = "shell-bench";
    };
  }
