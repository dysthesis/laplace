# https://github.com/maralorn/nix-output-monitor/pull/321
# Remove this patch when nixpkgs includes the upstream fix.
final: prev: {
  nix-output-monitor = prev.nix-output-monitor.override (old: {
    extraComposeFunctions =
      (old.extraComposeFunctions or [])
      ++ [
        (prev.haskell.lib.compose.appendPatch (prev.fetchpatch2 {
          name = "nix-output-monitor-unknown-events.patch";
          url = "https://github.com/maralorn/nix-output-monitor/compare/c40cb120262d9e9b1b988898708b124f6ffc0913...202f940f96360548dedfb3b9234f6f6f08a9a2ba.patch";
          relative = "nix-output-monitor";
          hash = "sha256-d20jaA7iTSZ+3s7fV2Ql//tfnpqu6lJQmpOX1kfy4V8=";
        }))
      ];
  });

  nh = prev.nh.override {
    inherit (final) nix-output-monitor;
  };
}
