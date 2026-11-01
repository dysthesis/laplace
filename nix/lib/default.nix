nixpkgs:
nixpkgs.lib.extend (
  final: _prev: let
    inherit (builtins) readDir attrNames;

    getModuleDirs = dir:
      dir
      |> readDir
      |> final.filterAttrs (name: type: type == "directory" && builtins.pathExists "${dir}/${name}/default.nix")
      |> attrNames;

    # Path addition keeps the flake context for relative imports.
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

        # `extra` adds enum values that have no module directory.
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

      # `args` accepts a wrapper specification or shell code for `postBuild`.
      # Each `addFlags` item becomes one argument.
      # PATH contains `binPath` directories before host directories.
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
          # The join puts all selected package outputs in `out`.
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
