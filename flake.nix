{
  description = "A pursuit of order.";
  inputs = {
    # TODO: See if switching to unstable fixes
    # https://github.com/NixOS/nixpkgs/issues/222181
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs";

    # Formatter for the whole codebase
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    read = {
      url = "github:dysthesis/read";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Personal library
    babel = {
      url = "github:dysthesis/babel";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    status = {
      url = "github:dysthesis/status";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Neovim flake
    poincare = {
      url = "github:dysthesis/poincare";
      # TODO: enable this again when the fix for neotest makes it to unstable
      # inputs.nixpkgs.follows = "nixpkgs";
    };

    jormungandr = {
      url = "path:/home/demiurge/Documents/Projects/jormungandr";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Suckless utilities
    gungnir = {
      url = "github:dysthesis/gungnir";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # XMonad flake
    mandelbrot = {
      url = "github:dysthesis/mandelbrot";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # tmux flake
    daedalus = {
      url = "github:dysthesis/daedalus";
      # inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative disk management
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secure boot
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # A nice wrapper for Nix
    nh = {
      url = "github:viperML/nh";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # For some reason, this browser isn't in nixpkgs
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hardware QOL stuff for the Framework laptop
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    # Sandboxing utility
    nixpak = {
      url = "github:nixpak/nixpak";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Needed for comma
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secrets management
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      babel,
      nixpkgs,
      treefmt-nix,
      ...
    }:
    let
      inherit (builtins) mapAttrs;
      inherit (babel) mkLib;
      lib = mkLib nixpkgs;

      # Systems to support
      systems = [
        "aarch64-linux"
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      overlays = [
        (_self: super: {
          ggml = super.ggml.overrideAttrs (old: {
            CMAKE_FLAGS = (old.CMAKE_FLAGS or [ ]) ++ [
              "-DGGML_HIP=ON"
              "-DGGML_HIP_ARCHITECTURE=gfx1032"
            ];
          });
        })
      ];

      forAllSystems = lib.babel.forAllSystems { inherit systems overlays; };

      treefmt = forAllSystems (pkgs: treefmt-nix.lib.evalModule pkgs ./nix/formatters);
    in
    # Budget flake-parts
    mapAttrs (_: forAllSystems) {
      devShells = pkgs: { default = import ./nix/shell pkgs; };
      # for `nix fmt`
      formatter = pkgs: treefmt.${pkgs.system}.config.build.wrapper;
      # for `nix flake check`
      checks = pkgs: {
        formatting = treefmt.${pkgs.system}.config.build.check self;
      };
    }
    // {
      nixosConfigurations = import ./hosts {
        inherit self lib inputs;
      };
    };
}
