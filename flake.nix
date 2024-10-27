{
  description = "Description for the project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs?rev=58b124e48c790137071cb9bfc03733c5aa7073e5";

    episteme.url = "git+https://git.dysthesis.com/dysthesis/episteme.git";
    comp6841.url = "git+https://git.dysthesis.com/dysthesis/COMP6841-Tutoring.git";

    # Modularise your flake
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    # Get Nix to manage your home as well.
    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wezterm = {
      url = "github:wez/wezterm/main?dir=nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprpaper = {
      url = "github:hyprwm/hyprpaper";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hardware QOL stuff for the Framework laptop
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    # Automate the partitioning of disks
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    systems.url = "github:nix-systems/default-linux";

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Secure boot
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secrets management
    sops-nix.url = "github:Mic92/sops-nix";

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
      # inputs = {
      #   nixpkgs.follows = "nixpkgs";
      #   flake-parts.follows = "flake-parts";
      #   systems.follows = "systems";
      #   treefmt.follows = "treefmt";
      # };
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

  outputs = inputs @ {flake-parts, ...}: let
    lib = import ./lib inputs;
  in
    flake-parts.lib.mkFlake {
      inherit inputs;
      specialArgs = {inherit lib;};
    } {
      imports = [
        ./flake
        ./hosts
      ];

      systems = import inputs.systems;
    };
}
