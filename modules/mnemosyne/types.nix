{ lib }:
let
  inherit (builtins) throw;
  inherit (lib)
    mkOption
    filter
    ;
  inherit (lib.types)
    bool
    listOf
    nullOr
    str
    enum
    submodule
    coercedTo
    ;
  inherit (lib.strings)
    hasPrefix
    hasSuffix
    splitString
    ;

  isAbsolute = path: hasPrefix "/" path;
  normalizedSegments = path: filter (segment: segment != "" && segment != ".") (splitString "/" path);
  hasParentSegments = path: lib.elem ".." (normalizedSegments path);

  ensureNonEmpty = name: value:
    if value == "" then
      throw "mnemosyne.${name} must not be empty"
    else
      value;

  ensureAbsolutePath = name: value:
    let
      path = ensureNonEmpty name value;
    in
    if !isAbsolute path then
      throw "mnemosyne.${name} must be an absolute path (got '${value}')"
    else if hasParentSegments path then
      throw "mnemosyne.${name} must not contain '..' segments (got '${value}')"
    else
      path;

  ensureAbsoluteNoTrailingSlash = name: value:
    let
      path = ensureAbsolutePath name value;
    in
    if path != "/" && hasSuffix "/" path then
      throw "mnemosyne.${name} must not end with a trailing slash (got '${value}')"
    else
      path;

  ensureRelativePath = name: value:
    let
      path = ensureNonEmpty name value;
    in
    if isAbsolute path then
      throw "mnemosyne.${name} must be a path relative to the user's home (got '${value}')"
    else if hasParentSegments path then
      throw "mnemosyne.${name} must not contain '..' segments (got '${value}')"
    else
      path;

  mountOptionsSubmodule = submodule ({ ... }: {
    options = {
      mode = mkOption {
        type = enum [ "append" "replace" ];
        default = "replace";
        description = "Whether to append to or replace the default directory mount options.";
      };
      options = mkOption {
        type = listOf str;
        default = [ ];
        description = "Mount options to merge with or replace the defaults.";
      };
    };
  });

  mountOptionsType = coercedTo (listOf str) (opts: {
    mode = "replace";
    options = opts;
  }) mountOptionsSubmodule;

  mkDirectoryEntryType = userName:
    coercedTo str (directory: { directory = directory; }) (submodule ({ config, ... }: {
      options = {
        directory = mkOption {
          type = str;
          description = "The directory path to persist, relative to the user's home.";
          apply = value: ensureRelativePath "users.${userName}.directories.directory" value;
        };
        mode = mkOption {
          type = nullOr str;
          default = null;
          description = "Optional permission mode for the persisted directory.";
        };
        user = mkOption {
          type = nullOr str;
          default = null;
          description = "Optional owner override for the persisted directory.";
        };
        group = mkOption {
          type = nullOr str;
          default = null;
          description = "Optional group override for the persisted directory.";
        };
        persistPathOverride = mkOption {
          type = nullOr str;
          default = null;
          apply = value:
            if value == null then null else ensureAbsolutePath "users.${userName}.directories.persistPathOverride" value;
          description = "Optional fully-qualified path inside the persistence store.";
        };
        mountOptions = mkOption {
          type = nullOr mountOptionsType;
          default = null;
          description = ''
            Optional mount-option customisation. Use a list to replace the
            defaults, or an attrset `{ mode = "append"; options = [...] ; }`
            to extend them.
          '';
        };
      };
    }));

  mkFileEntryType = userName:
    coercedTo str (file: { file = file; }) (submodule ({ config, ... }: {
      options = {
        file = mkOption {
          type = str;
          description = "The file path to persist, relative to the user's home.";
          apply = value: ensureRelativePath "users.${userName}.files.file" value;
        };
        mode = mkOption {
          type = nullOr str;
          default = null;
          description = "Optional permission mode for the persisted file.";
        };
        user = mkOption {
          type = nullOr str;
          default = null;
          description = "Optional owner override for the persisted file.";
        };
        group = mkOption {
          type = nullOr str;
          default = null;
          description = "Optional group override for the persisted file.";
        };
        persistPathOverride = mkOption {
          type = nullOr str;
          default = null;
          apply = value:
            if value == null then null else ensureAbsolutePath "users.${userName}.files.persistPathOverride" value;
          description = "Optional fully-qualified path inside the persistence store.";
        };
        mountOptions = mkOption {
          type = nullOr mountOptionsType;
          default = null;
          description = ''
            Optional mount-option customisation. Use a list to replace the
            defaults, or an attrset `{ mode = "append"; options = [...] ; }`
            to extend them.
          '';
        };
        linkMethod = mkOption {
          type = enum [ "bind" "symlink" ];
          default = "bind";
          description = "Whether to bind-mount the file or create a symlink into persistent storage.";
        };
      };
    }));

  userPersistenceModule = name: {
    options = {
      enable = mkOption {
        type = bool;
        default = true;
        description = "Whether to enable persistence entries for this user.";
      };
      home = mkOption {
        type = str;
        default = "/home/${name}";
        description = "Absolute path to the user's home directory.";
        apply = value: ensureAbsolutePath "users.${name}.home" value;
      };
      persistSubdir = mkOption {
        type = nullOr str;
        default = null;
        description = "Optional subdirectory under `mnemosyne.persistDir` dedicated to this user.";
        apply = value:
          if value == null then null else ensureAbsoluteNoTrailingSlash "users.${name}.persistSubdir" value;
      };
      directories = mkOption {
        type = listOf (mkDirectoryEntryType name);
        default = [ ];
        description = "Directories relative to the user's home that should be persisted.";
      };
      files = mkOption {
        type = listOf (mkFileEntryType name);
        default = [ ];
        description = "Files relative to the user's home that should be persisted.";
      };
    };
  };

  userPersistenceType = name: nullOr (submodule ({ ... }: userPersistenceModule name));

in
{
  inherit
    ensureAbsolutePath
    ensureAbsoluteNoTrailingSlash
    ensureRelativePath
    mountOptionsType
    mkDirectoryEntryType
    mkFileEntryType
    userPersistenceModule
    userPersistenceType;
}
