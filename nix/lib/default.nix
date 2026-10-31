nixpkgs:
nixpkgs.lib.extend (
  final: _prev: let
    inherit (builtins) readDir attrNames;

    # Select only child directories with default.nix.
    getModuleDirs = dir:
      dir
      |> readDir
      |> final.filterAttrs (name: type: type == "directory" && builtins.pathExists "${dir}/${name}/default.nix")
      |> attrNames;

    # Path addition preserves flake context and relative imports.
    importInDirectory = dir:
      dir
      |> getModuleDirs
      |> map (module: dir + "/${module}");
  in {
    laplace = {
      forAllSystems = {
        pkgs ? nixpkgs,
        overlays ? [],
        systems ? [],
      }: f:
        final.genAttrs systems (
          system: f (import pkgs {inherit system overlays;})
        );

      telemetry = import ../../system/services/telemetry/contract.nix {lib = final;};

      modules = {
        inherit importInDirectory;

        # Imports child modules and exposes their names as an enum option.
        # multiple selects a list; extra adds names outside the directory.
        mkSelector = {
          dir,
          option,
          description ? "",
          multiple ? true,
          extra ? [],
          default ? (
            if multiple
            then []
            else throw "mkSelector: scalar selector '${final.showOption option}' needs an explicit `default`"
          ),
        }: let
          base = final.types.enum (getModuleDirs dir ++ extra);
        in {
          options = final.setAttrByPath option (final.mkOption {
            type =
              if multiple
              then final.types.listOf base
              else base;
            inherit default description;
          });
          imports = importInDirectory dir;
        };
      };

      # Wrap one or more binaries. args may be raw postBuild or a wrapper spec.
      # Spec keys: program, addFlags, set, binPath, run, and postBuild.
      # Each addFlags item is prepended as one argv.
      # binPath is prepended to PATH, so wrapper dependencies shadow host tools.
      # Values are escaped with escapeShellArgs.
      pkgs.mkWrapper = pkgs: package: args: let
        paths =
          if
            (!package ? outputSpecified || !package.outputSpecified)
            && package.meta.outputsToInstall or null != null
          then map (output: package.${output}) package.meta.outputsToInstall
          else [package];

        mainProgram = package.meta.mainProgram or (final.getName package);

        spec =
          if builtins.isString args
          then {postBuild = args;}
          else args;

        wrapperArgs =
          final.concatMap (f: ["--add-flag" f]) (spec.addFlags or [])
          ++ final.concatLists
          (final.mapAttrsToList (n: v: ["--set" n v])
            (spec.set or {}))
          ++ final.optionals
          ((spec.binPath or []) != [])
          ["--prefix" "PATH" ":" (final.makeBinPath spec.binPath)]
          ++ final.concatMap (c: ["--run" c]) (spec.run or []);

        wrapLine =
          final.optionalString (wrapperArgs != [])
          "wrapProgram $out/bin/${final.escapeShellArg
            (spec.program or mainProgram)} ${final.escapeShellArgs wrapperArgs}\n";
      in
        pkgs.symlinkJoin {
          inherit paths;
          postBuild = wrapLine + (spec.postBuild or "");
          name = "${final.getName package}-wrapped";
          buildInputs = [pkgs.makeWrapper];
          # Selected package outputs are flattened into the join's out.
          meta =
            (package.meta or {})
            // {
              inherit mainProgram;
              outputsToInstall = ["out"];
            };
        };
    };
  }
)
