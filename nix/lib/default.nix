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

      # Import every immediate subdirectory that is a module (has a
      # default.nix), so non-module data directories (e.g. assets) can live
      # alongside modules without being imported. Uses path concatenation
      # (not string interpolation) so imported modules stay within the flake
      # source tree and their relative paths resolve correctly.
      modules.importInDirectory = dir:
        dir
        |> getDirectories
        |> builtins.filter (module: builtins.pathExists "${dir}/${module}/default.nix")
        |> map (module: dir + "/${module}");

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
