# Exposes `pkgs.unstable`: nixpkgs-unstable evaluated for the host platform,
# inheriting the stable nixpkgs `config`. Use `pkgs.unstable.<pkg>` to reach a
# newer package without switching the whole system off the stable channel.
#
# Carries a mistral-common pin (see below) required by the unstable transformers
# package; drop it once nixpkgs-unstable ships mistral-common >= 1.11.
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
              # transformers 5.5 imports ReasoningEffort from mistral-common;
              # nixpkgs currently has 1.8.8, which lacks that symbol.
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
