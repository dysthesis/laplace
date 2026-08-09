nixpkgs:
nixpkgs.lib.extend (
  final: _prev: let
    inherit (builtins) readDir attrNames;

    getItemsOfType = dir: type:
      dir
      |> readDir
      |> final.filterAttrs (_name: value: value == type)
      |> attrNames;

    getDirectories = dir: getItemsOfType dir "directory";
    getFiles = dir: getItemsOfType dir "regular";

    # Select only child directories with default.nix.
    getModuleDirs = dir:
      dir
      |> getDirectories
      |> builtins.filter
      (module: builtins.pathExists "${dir}/${module}/default.nix");

    # Path addition preserves flake context and relative imports.
    importInDirectory = dir:
      dir
      |> getModuleDirs
      |> map (module: dir + "/${module}");

    # Shared module list and specialArgs for nixosConfigurations and Colmena.
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

        # Imports child modules and exposes their names as an enum option.
        # multiple selects a list; extra adds names; broken maps names to errors.
        # active gates broken-member checks for disabled features.
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

      # Wrap one or more binaries. args may be raw postBuild or a wrapper spec.
      # Spec keys: program, addFlags, set, binPath, run, and postBuild.
      # Each addFlags item is prepended as one argv.
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
          ++ final.concatLists (final.mapAttrsToList (n: v: ["--set" n v]) (spec.set or {}))
          ++ final.optionals ((spec.binPath or []) != []) ["--prefix" "PATH" ":" (final.makeBinPath spec.binPath)]
          ++ final.concatMap (c: ["--run" c]) (spec.run or []);
        wrapLine =
          final.optionalString (wrapperArgs != [])
          "wrapProgram $out/bin/${final.escapeShellArg (spec.program or mainProgram)} ${final.escapeShellArgs wrapperArgs}\n";
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

      system = {
        inherit mkSystemModules;
        mkSystem = args: final.nixosSystem (mkSystemModules args);
      };
    };
  }
)
