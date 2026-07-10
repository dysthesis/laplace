# Flake-local library, formerly sourced from the `nixpressions` flake.
# Only the helpers this configuration actually uses are kept here, exposed
# under the `laplace` namespace.
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

    # Immediate subdirectories that are modules (have a default.nix), so
    # non-module data directories (e.g. assets) can live alongside modules
    # without being imported or becoming selectable enum members.
    getModuleDirs = dir:
      dir
      |> getDirectories
      |> builtins.filter (module: builtins.pathExists "${dir}/${module}/default.nix");

    # Import every immediate module subdirectory. Uses path concatenation
    # (not string interpolation) so imported modules stay within the flake
    # source tree and their relative paths resolve correctly.
    importInDirectory = dir:
      dir
      |> getModuleDirs
      |> map (module: dir + "/${module}");

    # The module list + specialArgs that compose a host, factored out of
    # `mkSystem` so Colmena can consume the same modules (it must own the
    # nixosSystem call itself to inject its `deployment` namespace). One source
    # of truth for both `nixosConfigurations` and the `colmena` hive. See
    # nix/deploy and hosts/default.nix.
    mkSystemModules = {
      self,
      system,
      hostname,
      config,
      inputs,
      specialArgs,
      nixosProfiles ? [],
      extraModules ? [],
      ...
    }: {
      inherit system;
      specialArgs = {inherit self inputs;} // specialArgs;
      modules =
        [
          {networking.hostName = hostname;}
          {nixpkgs.hostPlatform = final.mkDefault system;}
          (
            {modulesPath, ...}: let
              profilesPath = "${modulesPath}/profiles";
              validProfiles = map (final.removeSuffix ".nix") (getFiles profilesPath);
            in
              (final.checkListOfEnum "valid modules" validProfiles nixosProfiles) {
                imports = map (profile: "${profilesPath}/${profile}.nix") nixosProfiles;
              }
          )
          config
        ]
        ++ extraModules;
    };
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
        #   broken   :: member name -> reason; the member stays selectable (so
        #               the reason is discoverable) but selecting it trips an
        #               assertion at eval instead of silently misbehaving
        #   active   :: config -> bool; gates the broken assertions so a broken
        #               *default* on a feature the host never enables (e.g. an
        #               xorg session on a wayland-only host) does not fail
        mkSelector = {
          dir,
          option,
          description ? "",
          multiple ? true,
          extra ? [],
          broken ? {},
          active ? (_config: true),
          default ? (
            if multiple
            then []
            else throw "mkSelector: scalar selector '${final.showOption option}' needs an explicit `default`"
          ),
        }: let
          base = final.types.enum (getModuleDirs dir ++ extra);
          brokenAssertions = {config, ...}: let
            value = final.getAttrFromPath option config;
            chosen =
              if multiple
              then value
              else [value];
          in {
            assertions =
              final.mapAttrsToList (member: reason: {
                assertion = !(active config && builtins.elem member chosen);
                message = "${final.showOption option}: '${member}' is known broken: ${reason}";
              })
              broken;
          };
        in {
          options = final.setAttrByPath option (final.mkOption {
            type =
              if multiple
              then final.types.listOf base
              else base;
            inherit default description;
          });
          imports = importInDirectory dir ++ final.optional (broken != {}) brokenAssertions;
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

      system = {
        inherit mkSystemModules;
        mkSystem = args: final.nixosSystem (mkSystemModules args);
      };
    };
  }
)
