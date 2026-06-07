# Flake-local library, formerly sourced from the `nixpressions` flake.
# Only the helpers this configuration actually uses are kept here; the
# `babel` namespace is preserved so existing call sites need no changes.
nixpkgs:
nixpkgs.lib.extend (
  final: _prev: let
    inherit (builtins) readDir attrNames isList elemAt;

    getItemsOfType = dir: type:
      dir
      |> readDir
      |> final.filterAttrs (_name: value: value == type)
      |> attrNames;

    getDirectories = dir: getItemsOfType dir "directory";
    getFiles = dir: getItemsOfType dir "regular";

    # Import every immediate subdirectory that is a module (has a default.nix),
    # so non-module data directories (e.g. assets) can live alongside modules
    # without being imported. Uses path concatenation (not string
    # interpolation) so imported modules stay within the flake source tree and
    # their relative paths resolve correctly.
    importInDirectory = dir:
      dir
      |> getDirectories
      |> builtins.filter (module: builtins.pathExists "${dir}/${module}/default.nix")
      |> map (module: dir + "/${module}");
  in {
    babel = {
      forAllSystems = {
        pkgs ? nixpkgs,
        overlays ? [],
        systems ? [],
      }: f:
        final.genAttrs systems (
          system: f (import pkgs {inherit system overlays;})
        );

      path = {inherit getItemsOfType getDirectories getFiles;};

      modules = {
        inherit importInDirectory;

        # Declarative "selector" module: derive an enum from the names of the
        # immediate subdirectories of `dir`, expose it as the option at the
        # attribute path `option`, and import every child (each child gates
        # itself on this option via `mkIf`). Collapses the repeated
        # getDirectories + mkOption + importInDirectory boilerplate.
        #
        #   option   :: attr-path segments, e.g. ["laplace" "hardware" "cpu"]
        #   multiple :: true  -> listOf (enum members), default []
        #               false -> enum members, explicit `default` required
        #   extra    :: extra enum members beyond the subdir names, e.g. ["none"]
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
          base = final.types.enum (getDirectories dir ++ extra);
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

      # Wraps a binary (or list of binaries) with the given postBuild snippet,
      # carrying through the original mainProgram.
      pkgs.mkWrapper = pkgs: package: postBuild: let
        target =
          if isList package
          then elemAt package 0
          else package;
        paths =
          if isList package
          then package
          else [package];
      in
        pkgs.symlinkJoin {
          inherit paths postBuild;
          name = "${target}-wrapped";
          buildInputs = [pkgs.makeWrapper];
          meta = {inherit (target.meta) mainProgram;};
        };

      system.mkSystem = {
        self,
        system,
        hostname,
        config,
        inputs,
        specialArgs,
        profiles ? [],
        extraModules ? [],
        ...
      }:
        final.nixosSystem {
          inherit system;
          modules =
            [
              {networking.hostName = hostname;}
              {nixpkgs.hostPlatform = final.mkDefault system;}
              (
                {modulesPath, ...}: let
                  profilesPath = "${modulesPath}/profiles";
                  validProfiles = map (final.removeSuffix ".nix") (getFiles profilesPath);
                in
                  (final.checkListOfEnum "valid modules" validProfiles profiles) {
                    imports = map (profile: "${profilesPath}/${profile}.nix") profiles;
                  }
              )
              config
            ]
            ++ extraModules;
          specialArgs = {inherit self inputs;} // specialArgs;
        };
    };
  }
)
