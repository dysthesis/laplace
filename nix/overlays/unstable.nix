# Exposes host-platform pkgs.unstable with stable nixpkgs config.
# Pin mistral-common until nixpkgs-unstable reaches 1.11.
inputs: final: _prev: {
  unstable = import inputs.nixpkgs-unstable {
    system = final.stdenv.hostPlatform.system;
    inherit (final) config;
    overlays = [
      (unstableFinal: unstablePrev: {
        pythonPackagesExtensions =
          (unstablePrev.pythonPackagesExtensions or [])
          ++ [
            (_pythonFinal: pythonPrev: {
              # transformers 5.5 needs ReasoningEffort, absent in 1.8.8.
              mistral-common = pythonPrev.mistral-common.overridePythonAttrs (old: rec {
                version = "1.11.1";
                src = unstableFinal.fetchFromGitHub {
                  owner = "mistralai";
                  repo = "mistral-common";
                  tag = "v${version}";
                  hash = "sha256-wmU5keSAVLYD5LUkqKjNrXbKWxLHpXOEjUjCRCFsqN4=";
                };
                dependencies = (old.dependencies or []) ++ [pythonPrev.pycountry];
                disabledTestPaths = (old.disabledTestPaths or []) ++ ["tests/guidance"];
              });
            })
          ];
      })
    ];
  };
}
