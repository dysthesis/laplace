{
  description = "A pursuit of order.";

  outputs = inputs @ {
    self,
    nixpkgs,
    treefmt-nix,
    ...
  }: let
    inherit (builtins) mapAttrs;
    lib = import ./nix/lib nixpkgs;

    systems = [
      "aarch64-linux"
      "x86_64-linux"
      "aarch64-darwin"
    ];

    forAllSystems = lib.laplace.forAllSystems {
      inherit systems;
      overlays = [self.overlays.linux-hardened];
    };

    treefmt =
      forAllSystems
      (pkgs: treefmt-nix.lib.evalModule pkgs ./nix/formatters);
    cluster = import ./cluster {inherit lib;};
    hosts = import ./hosts {inherit self lib inputs cluster;};
    inherit (hosts) nixosConfigurations;
  in
    mapAttrs (_: forAllSystems)
    {
      devShells = pkgs: let
        nixpkgs-unstable = import inputs.nixpkgs-unstable {system = pkgs.stdenv.hostPlatform.system;};
      in {default = import ./nix/shell nixpkgs-unstable;};

      packages = pkgs:
        lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux
        {
          linux-hardened = pkgs.linux_hardened;
        }
        // lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
          linux-hardened-boot-test = import ./nix/tests/linux-hardened-boot.nix {inherit pkgs;};
        };

      apps = pkgs:
        lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          bench = {
            type = "app";
            program = lib.getExe (import ./bench pkgs);
          };
        };
      formatter = pkgs: treefmt.${pkgs.stdenv.hostPlatform.system}.config.build.wrapper;
      checks = pkgs:
        {
          formatting = treefmt.${pkgs.stdenv.hostPlatform.system}.config.build.check self;
        }
        // lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux")
        (import ./nix/tests {inherit pkgs lib inputs self cluster nixosConfigurations;});
    }
    // {
      overlays = {
        linux-hardened = import ./nix/overlays/linux-hardened.nix;
        default = self.overlays.linux-hardened;
      };

      inherit nixosConfigurations;
      laplace = cluster.manifest;
      telemetryRotationPlan = import ./system/services/telemetry/rotation-plan.nix {
        inherit lib nixosConfigurations;
        cluster = cluster.manifest;
        sourceRoot = ./.;
      };

      colmena = import ./nix/deploy {
        inherit self inputs lib;
        inherit (hosts) nodeModules;
        cluster = cluster.manifest;
      };

      colmenaHive = inputs.colmena.lib.makeHive self.outputs.colmena;
    };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Use a channel revision for Hydra substitutes.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # This fork must use the Go toolchain from its own nixpkgs input.
    headscale.url = "github:dysthesis/headscale?ref=feat/wg-only-peers";

    poincare = {
      url = "github:dysthesis/poincare";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    serena = {
      url = "github:oraios/serena";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    dwl = {
      url = "github:dysthesis/dwl";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # gungnir does not build with Determinate Nix. Xorg is disabled on all hosts.
    gungnir = {
      url = "github:dysthesis/gungnir";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mandelbrot = {
      url = "github:dysthesis/mandelbrot";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    daedalus = {
      url = "github:dysthesis/daedalus";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    oh-my-pi = {
      url = "github:can1357/oh-my-pi/v18.12.6";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware";

    nixpak = {
      url = "github:nixpak/nixpak";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    status = {
      url = "github:dysthesis/status";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-minecraft = {
      url = "github:Infinidoge/nix-minecraft";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    iosevka-cadmus = {
      url = "github:dysthesis/iosevka-cadmus";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    colmena.url = "github:nix-community/colmena";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
  };
}
