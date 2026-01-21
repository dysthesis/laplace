{
  description = "A pursuit of order.";

  outputs = inputs @ {
    self,
    nixpressions,
    nixpkgs,
    treefmt-nix,
    emacs,
    ...
  }: let
    inherit (builtins) mapAttrs;
    inherit (nixpressions) mkLib;
    lib = mkLib nixpkgs;

    # Systems to support
    systems = [
      "aarch64-linux"
      "x86_64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];

    overlays = [emacs.overlays.default];

    forAllSystems = lib.babel.forAllSystems {inherit systems overlays;};

    treefmt = forAllSystems (pkgs: treefmt-nix.lib.evalModule pkgs ./nix/formatters);
    nixosConfigurations = import ./hosts {inherit self lib inputs;};
    hostnames = builtins.attrNames nixosConfigurations;
    mkAnywhereApps = pkgs: let
      anywherePkg = lib.attrByPath [pkgs.system "nixos-anywhere"] null inputs.nixos-anywhere.packages;
    in
      if anywherePkg == null
      then {}
      else
        builtins.listToAttrs (
          map (
            hostname: let
              script = pkgs.writeShellApplication {
                name = "install-${hostname}";
                runtimeInputs = [
                  pkgs.coreutils
                  pkgs.gum
                ];
                text = ''
                  set -euo pipefail

                  tmp="$(mktemp -d)"
                  cleanup() {
                    rm -rf "$tmp"
                  }
                  trap cleanup EXIT

                  umask 077
                  password_file="$tmp/luks.key"

                  if [ -n "''${LUKS_PASSWORD_FILE:-}" ]; then
                    cp "''${LUKS_PASSWORD_FILE}" "$password_file"
                    chmod 600 "$password_file"
                  else
                    echo "Enter the disk encryption password for ${hostname} (input hidden):" >&2
                    passphrase="$(${pkgs.gum}/bin/gum input --password --prompt "LUKS passphrase: ")"
                    if [ -z "$passphrase" ]; then
                      echo "ERROR: disk encryption password cannot be empty." >&2
                      exit 1
                    fi
                    printf '%s' "$passphrase" >"$password_file"
                    chmod 600 "$password_file"
                    unset passphrase
                  fi

                  FLAKE_REF="''${FLAKE_REF:-${self.outPath}}"
                  exec ${anywherePkg}/bin/nixos-anywhere \
                    --disk-encryption-keys /tmp/luks.key "$password_file" \
                    --flake "''${FLAKE_REF}#${hostname}" "$@"
                '';
              };
            in {
              name = "install-${hostname}";
              value = {
                type = "app";
                program = "${script}/bin/install-${hostname}";
              };
            }
          )
          hostnames
        );
    # Budget flake-parts
  in
    mapAttrs (_: forAllSystems) {
      devShells = pkgs: {default = import ./nix/shell pkgs;};
      # for `nix fmt`
      formatter = pkgs: treefmt.${pkgs.system}.config.build.wrapper;
      # for `nix flake check`
      checks = pkgs: {
        formatting = treefmt.${pkgs.system}.config.build.check self;
      };
      # WARN: Very WIP
      apps = mkAnywhereApps;
    }
    // {
      inherit nixosConfigurations;
    };

  inputs = {
    # TODO: See if switching to unstable fixes
    # https://github.com/NixOS/nixpkgs/issues/222181
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs";

    # Supposedly faster Nix.
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    nix-ai-tools = {
      url = "github:numtide/nix-ai-tools";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    emacs = {
      url = "github:nix-community/emacs-overlay";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.nixpkgs-stable.follows = "nixpkgs";
    };

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
    nixpressions = {
      url = "github:dysthesis/nixpressions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    status = {
      url = "github:dysthesis/status";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Neovim flake
    poincare = {
      url = "github:dysthesis/poincare";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    dwl = {
      url = "github:dysthesis/dwl";
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
      # inputs.nixpkgs.follows = "nixpkgs-unstable";
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
      url = "github:0xc000022070/zen-browser-flake";
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

    # Personal Nix flake
    jormungandr = {
      url = "github:dysthesis/jormungandr";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # Secrets management
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
