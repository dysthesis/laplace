{
  inputs,
  self,
  lib,
  ...
}: let
  inherit (lib.babel.system) mkSystem;
  inherit (builtins) mapAttrs;
  hosts = {
    erebus = "aarch64-linux"; # Raspberry Pi
    phobos = "x86_64-linux"; # Laptop
    deimos = "x86_64-linux"; # PC
    chaos = "x86_64-linux"; # Installer ISO
  };
  defaultImports = [
    ../system
    ../modules
    ../user
    inputs.disko.nixosModules.disko
    inputs.nix-index-database.darwinModules.nix-index
  ];
  extraModules = [inputs.determinate.nixosModules.default];
in
  mapAttrs (
    hostname: system:
      mkSystem {
        inherit
          system
          hostname
          self
          inputs
          extraModules
          ;
        # BUG: For some reason, wifi is fucked if I import the hardened.nix profile,
        # but not if I add all of the options myself manually. This is so fucking weird.
        profiles = ["minimal"];
        specialArgs = {inherit lib;};
        config = {
          documentation.man.enable = true;
          programs.nix-index-database.comma.enable = true;
          # Use stable nixpkgs by default, but allow accessing unstable packages
          # by using `pkgs.unstable`
          nixpkgs.overlays = [
            self.overlays.linux-hardened
            (final: _prev: {
              # Provide a non-aliased `system` attribute to avoid deprecation warnings.
              system = final.stdenv.hostPlatform.system;
            })
            (final: _prev: {
              unstable = import inputs.nixpkgs-unstable {
                system = final.stdenv.hostPlatform.system;
                config = final.config;
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
            })
            # Silence the deprecated `pkgs.system` alias warning without hiding other warnings.
            (_final: prev: let
              prevLib = prev.lib;
              suppressMsg = msg: let
                s = toString msg;
              in
                builtins.match ".*has been renamed to/replaced by 'stdenv\\.hostPlatform\\.system'.*" s != null;
            in {
              lib =
                prevLib
                // {
                  warn = msg: val:
                    if suppressMsg msg
                    then val
                    else prevLib.warn msg val;
                };
            })
          ];
          imports =
            [
              ./${hostname}
            ]
            ++ defaultImports;
        };
      }
  )
  hosts
