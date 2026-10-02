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

              torch = pythonPrev.torch.overrideAttrs (old:
                unstableFinal.lib.optionalAttrs old.passthru.rocmSupport {
                  # CMake runs this CK helper before the fixup shebang hook.
                  postPatch =
                    (old.postPatch or "")
                    + ''
                      patchShebangs --build aten/src/ATen/native/transformers/hip/flash_attn/ck/add_make_kernel_pt.sh
                    '';

                  # Parse libstdc++ before HIP defines its __noinline__ macro.
                  # CMake's CXXFLAGS initialization keeps this out of C/HIP flags.
                  preConfigure =
                    (old.preConfigure or "")
                    + ''
                      export CXXFLAGS="''${CXXFLAGS-} ''${CMAKE_CXX_FLAGS-} -include chrono"
                    '';
                });
            })
          ];
      })
    ];
  };
}
