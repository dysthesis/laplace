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

    # The linux-hardened overlay is baked in here so `pkgs.linux_hardened` is
    # available to the `packages` output and the boot-test check (hosts apply
    # it separately via hosts/default.nix).
    forAllSystems = lib.laplace.forAllSystems {
      inherit systems;
      overlays = [self.overlays.linux-hardened];
    };

    treefmt =
      forAllSystems
      (pkgs: treefmt-nix.lib.evalModule pkgs ./nix/formatters);
    hosts = import ./hosts {inherit self lib inputs;};
    inherit (hosts) nixosConfigurations;
  in
    mapAttrs (_: forAllSystems)
    {
      devShells = pkgs: {default = import ./nix/shell pkgs;};
      # The hardened kernel (`nix build .#linux-hardened`) and its on-demand
      # QEMU boot test. The boot test lives here, not in `checks`, because it
      # compiles the kernel — keeping it out of `nix flake check` leaves CI
      # light. Verify the kernel boots explicitly with:
      #   nix build .#linux-hardened-boot-test
      packages = pkgs:
        lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux
        {
          linux-hardened = pkgs.linux_hardened;
        }
        // lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
          linux-hardened-boot-test = import ./nix/tests/linux-hardened-boot.nix {inherit pkgs;};
        };
      # Reproducible shell-startup benchmark: `nix run .#bench`. See bench/README.md.
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
        // lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
          # Each selected compositor/session module contributes its own
          # validation via laplace.display.checkCommands, so this check
          # follows compositor swaps without edits here.
          desktop-stack = let
            validateHost = name: host:
              lib.optionalString (host.config.laplace.display.checkCommands != []) ''
                echo "validating ${name}"
                ${lib.concatStrings host.config.laplace.display.checkCommands}
              '';
          in
            pkgs.runCommand "desktop-configs" {} ''
              ${lib.concatStrings (lib.mapAttrsToList validateHost nixosConfigurations)}
              touch $out
            '';

          # Build-time half of PLAN §5 layer 4: gate the SSOT-rendered Headscale
          # policy and rendered service config against the same headscale binary
          # bifrost runs. configtest needs writable state paths, so the sandbox
          # copies the rendered config and rewrites only /var/lib + /run paths to
          # $TMPDIR. toJSON guarantees well-formed HuJSON, but only the control
          # plane catches semantic faults (undefined tag/alias, empty group). The
          # eval-time checkTailnet invariants
          # (system/tailnet/default.nix) already fire fleet-wide; this is the
          # remaining check the build sandbox CAN run (no network/db needed).
          # Runtime tag reconcile (gotcha 4) is `just tailnet-reconcile`, not a
          # check here — the sandbox has no network.
          headscale-policy = let
            headscalePackage = nixosConfigurations.bifrost.config.services.headscale.package;
          in
            pkgs.runCommand "headscale-policy-check"
            {
              nativeBuildInputs = [headscalePackage];
            } ''
              config="$TMPDIR/headscale.yaml"
              cp ${nixosConfigurations.bifrost.config.services.headscale.configFile} "$config"
              substituteInPlace "$config" \
                --replace-fail /var/lib/headscale "$TMPDIR/state" \
                --replace-fail /run/headscale "$TMPDIR/run"
              mkdir -p "$TMPDIR/state" "$TMPDIR/run"

              headscale --force configtest --config "$config"
              headscale --force policy check \
                --bypass-grpc-and-access-database-directly \
                --config "$config" \
                --file ${nixosConfigurations.bifrost.config.laplace.services.headscale.acl.policyFile}
              touch $out
            '';

          tailnet-reconcile = pkgs.runCommand "tailnet-reconcile-check" {nativeBuildInputs = [pkgs.jq];} ''
            ssot='{
              "alpha":{"ip":"100.64.0.1","ip6":"fd7a:115c:a1e0::1","tags":["infra","monitor"]},
              "beta":{"ip":"100.64.0.2","ip6":"fd7a:115c:a1e0::2","tags":["infra"]}
            }'
            problems=$(jq -r --argjson ssot "$ssot" -f ${./system/tailnet/reconcile.jq} <<'JSON'
            [
              {
                "name":"wrong-name",
                "given_name":"alpha",
                "ip_addresses":["100.64.0.9","fd7a:115c:a1e0::9"],
                "tags":["tag:infra"]
              },
              {
                "name":"gamma",
                "given_name":"gamma",
                "ip_addresses":["100.64.0.3","fd7a:115c:a1e0::3"],
                "tags":["tag:game"]
              },
              {
                "name":"guest",
                "given_name":"guest",
                "ip_addresses":["100.64.0.4","fd7a:115c:a1e0::4"],
                "tags":[]
              },
              {
                "name":"guest-copy",
                "given_name":"guest",
                "ip_addresses":["100.64.0.5","fd7a:115c:a1e0::5"],
                "tags":[]
              }
            ]
            JSON
            )
            expected=$(printf '%s\n' \
              'TAG DRIFT alpha: live=infra ssot=infra,monitor' \
              'ADDRESS DRIFT alpha: live=100.64.0.9,fd7a:115c:a1e0::9 ssot=100.64.0.1,fd7a:115c:a1e0::1' \
              'MISSING from tailnet: beta' \
              'UNEXPECTED tagged tailnet node: gamma' \
              'DUPLICATE tailnet node identity: guest')
            test "$problems" = "$expected"
            touch $out
          '';
        };
    }
    // {
      overlays = {
        linux-hardened = import ./nix/overlays/linux-hardened.nix;
        default = self.overlays.linux-hardened;
      };

      inherit nixosConfigurations;

      # Push-deploy hive for the Proxmox guests: `colmena apply --on @proxmox`
      # (or `just deploy`). See nix/deploy.
      colmena = import ./nix/deploy {
        inherit self inputs lib;
        inherit (hosts) nodeModules overlays;
      };
    };

  inputs = {
    # TODO: See if switching to unstable fixes
    # https://github.com/NixOS/nixpkgs/issues/222181
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs";

    # Supposedly faster Nix.
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    read = {
      url = "github:dysthesis/read";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Keep fork's own nixpkgs pin: it carries the Go toolchain revision used by
    # this headscale fork.
    headscale.url = "github:dysthesis/headscale?ref=feat/wg-only-peers";

    # Neovim flake
    poincare = {
      url = "github:dysthesis/poincare";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    dwl = {
      url = "github:dysthesis/dwl";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Suckless suite (st, dmenu, xsecurelock) for the xorg session.
    # NOTE: gungnir's `packages` output currently fails to evaluate under
    # Determinate Nix. The xorg path in system/users/demiurge is lazy and
    # unused (no host enables it), so this stays dormant until gungnir is
    # fixed upstream; restoring the input only resolves the dangling ref.
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
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secure boot
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
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

    # Self-hosted web history search. Needs Go 1.26 → follow nixpkgs-unstable
    # (26.05 pin is too old), reusing the existing unstable input rather than a
    # third nixpkgs instance.
    hister = {
      url = "github:asciimoo/hister";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };
}
