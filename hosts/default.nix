{ self, lib, inputs, ... }:
let
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  inherit (lib.laplace) mkSystem;
  inherit (builtins) mapAttrs;
  inherit (pkgs) linuxPackagesFor linuxKernel;

  # Map each host to its architecture
  hosts = {
    "yaldabaoth" = "x86_64-linux";
    "astaphaios" = "x86_64-linux";
    "adonaios" = "x86_64-linux";
  };
in {
  flake.nixosConfigurations = mapAttrs (hostname: system:
    mkSystem {
      inherit system hostname self;
      specialArgs = { inherit lib; };
      config =
        [ ./${hostname} "${self}/modules/system" "${self}/modules/secrets" ];
    }) hosts // {
      iso = lib.nixosSystem rec {
        system = "x86_64-linux";
        modules = [
          ({ modulesPath, ... }: {
            imports = let cd-drv = "installation-cd-graphical-gnome";
            in [ "${modulesPath}/installer/cd-dvd/${cd-drv}.nix" ];

            environment.systemPackages = with pkgs;
              let
                ghostty-config = writeText "ghostty-config" ''
                  adjust-cell-height = 20%
                  font-family = JetBrainsMono Nerd Font
                  font-feature = calt
                  font-feature = clig
                  font-feature = liga
                  font-feature = ss20
                  font-feature = cv02
                  font-feature = cv03
                  font-feature = cv04
                  font-feature = cv05
                  font-feature = cv06
                  font-feature = cv07
                  font-feature = cv11
                  font-feature = cv14
                  font-feature = cv15
                  font-feature = cv16
                  font-feature = cv17
                  font-size = 9
                  window-padding-x = 20
                  window-padding-y = 20

                  ## Lackluster
                  # https://github.com/slugbyte/lackluster.nvim/blob/662fba7e6719b7afc155076385c00d79290bc347/extra/ghostty/lackluster

                  palette = 0=#080808
                  palette = 1=#d70000
                  palette = 2=#789978
                  palette = 3=#ffaa88
                  palette = 4=#7788aa
                  palette = 5=#d7007d
                  palette = 6=#708090
                  palette = 7=#deeeed
                  palette = 8=#444444
                  palette = 9=#d70000
                  palette = 10=#789978
                  palette = 11=#ffaa88
                  palette = 12=#7788aa
                  palette = 13=#d7007d
                  palette = 14=#708090
                  palette = 15=#deeeed
                  background = 000000
                  foreground = deeeed
                  cursor-color = deeeed
                  selection-background = 7a7a7a
                  selection-foreground = 0a0a0a
                '';
                ghostty-wrapped = symlinkJoin {
                  name = "ghostty-wrapped";
                  paths =
                    [ inputs.babel.packages.${pkgs.system}.ghostty-hardened ];
                  buildInputs = [ makeWrapper ];
                  postBuild =
                    # sh
                    ''
                      wrapProgram $out/bin/ghostty --add-flags "--config-file=${ghostty-config}"
                    '';
                };
              in [
                inputs.daedalus.packages.${system}.default
                inputs.poincare.packages.${system}.default
                ghostty-wrapped
                nerd-fonts.jetbrains-mono
              ];

            documentation = {
              enable = lib.mkForce false;
              man.enable = lib.mkForce false;
              doc.enable = lib.mkForce false;
              info.enable = lib.mkForce false;
              nixos.enable = lib.mkForce false;
            };

            installer.cloneConfig = lib.mkForce false;

            # Use the latest kernel packages!
            boot.kernelPackages =
              linuxPackagesFor linuxKernel.kernels.linux_hardened;

            isoImage = {
              edition = lib.mkForce "erebus";
              isoName = lib.mkForce "NixOS";
            };

            nix = {
              package = pkgs.nixVersions.stable;
              settings = {
                experimental-features =
                  [ "nix-command" "flakes" "pipe-operators" ];
                auto-optimise-store = true;
              };
            };

            system.stateVersion = "24.11";
            networking.hostName = "erebus";
            nixpkgs.hostPlatform = "x86_64-linux";
          })
        ];
      };
    };
}
