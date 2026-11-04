# Pin benchmark tools, but use the caller's Nix for builds.
pkgs: let
  inherit (pkgs) lib;
  tools = lib.makeBinPath (with pkgs; [
    hyperfine
    strace
    python3
    jq
    util-linux # taskset
    coreutils
    gnused
    gnugrep
    findutils
    git
    fish # Use an unwrapped shell to measure init costs.
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
      for f in shell-bench.sh lib.sh pty-probe.py stats.py README.md; do
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
