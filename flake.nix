{
  description = "Description for the project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Modularise your flake
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    # Get Nix to manage your home as well.
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hardware QOL stuff for the Framework laptop
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    systems.url = "github:nix-systems/default-linux";

    # Secure boot
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    /*
    * The name here is quite contradictory, as _impermanence_ refers to wiping your root on every
    * boot (or putting it on tmpfs) and having Nix rebuild everything, hence discarding any state.
    *
    * The impermanence project provides utilities to provide persistence to the state that you _do_
    * want to keep.
    */
    impermanence.url = "github:nix-community/impermanence";

    # My own Neovim flake
    poincare = {
      url = "github:dysthesis/poincare";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        systems.follows = "systems";
        treefmt.follows = "treefmt";
      };
    };

    # A nice wrapper for Nix
    nh = {
      url = "github:viperML/nh";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Format your entire codebase
    treefmt = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        ./flake
      ];

      systems = import inputs.systems;
    };
}
