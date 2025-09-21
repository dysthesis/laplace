# Adapted from https://github.com/sioodmy/dotfiles/blob/1c692cbf6af349a568eb6ca2213eefbc42c43f39/modules/staypls/default.nix
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    attrNames
    concatMap
    filter
    filterAttrs
    foldl'
    mapAttrs
    map
    mkIf
    mkDefault
    mkMerge
    mkAfter
    recursiveUpdate
    forEach
    ;
  inherit (lib.attrsets)
    hasAttr
    ;
  inherit (lib.strings)
    concatStringsSep
    normalizePath
    removePrefix
    splitString
    hasPrefix
    ;
  inherit (lib)
    escapeShellArg
    ;
  inherit (builtins)
    dirOf
    head
    replaceStrings;
  cfg = config.mnemosyne;
  mountFileHelper = pkgs.runCommand "mnemosyne-mount-file" { buildInputs = [ pkgs.bash ]; } ''
    cp ${../impermanence/mount-file.bash} $out
    patchShebangs $out
  '';
  # Path helpers for system entries.
  persistPath = path: normalizePath "${cfg.persistDir}${path}";
  # Systemd mount unit backing the persistence volume.
  persistMountService =
    cfg.persistDir |> removePrefix "/" |> replaceStrings [ "/" ] [ "-" ] |> (x: "${x}.mount");
  # Canonical permissions for system-owned persisted directories.
  systemDirectoryDefaults = {
    user = "root";
    group = "root";
    mode = "0755";
  };
  # Normalized representation of system persistence directories.
  systemDirectoryEntries =
    map
      (path: {
        kind = "directory";
        origin = "system";
        relativePath = path;
        targetPath = path;
        persistentPath = persistPath path;
        owner = systemDirectoryDefaults;
        mountOptions = cfg.mountOpts;
      })
      cfg.dirs;
  joinPath = base: rel:
    if rel == "" then normalizePath base else normalizePath "${base}/${rel}";

  firstSegment = path:
    let
      segments = filter (segment: segment != "") (splitString "/" path);
    in
    if segments == [ ] then path else head segments;

  isHiddenPath = path: hasPrefix "." (firstSegment path);

  defaultUserDirMode = path: if isHiddenPath path then "0700" else "0755";
  defaultUserFileMode = path: if isHiddenPath path then "0600" else "0644";

  systemUsers = config.users.users or { };
  systemGroups = config.users.groups or { };

  inlineUserConfigs =
    mapAttrs (name: user: user.mnemosyne)
      (filterAttrs (_: user: (user.mnemosyne or null) != null) systemUsers);

  combinedUserConfigs = recursiveUpdate inlineUserConfigs cfg.users;

  findDuplicates = values:
    let
      counts = foldl'
        (acc: value:
          acc // {
            "${value}" = (acc.${value} or 0) + 1;
          })
        { }
        values;
    in
    attrNames (filterAttrs (_: count: count > 1) counts);

  requireSystemUser = userName:
    if hasAttr userName systemUsers then
      systemUsers.${userName}
    else
      throw "mnemosyne.users.${userName}: user must exist in users.users";

  ensureOverrideUser = location: userName:
    if hasAttr userName systemUsers then
      userName
    else
      throw "mnemosyne.${location}: referenced user '${userName}' is not declared in users.users";

  ensureOverrideGroup = location: groupName:
    if hasAttr groupName systemGroups then
      groupName
    else
      throw "mnemosyne.${location}: referenced group '${groupName}' is not declared in users.groups";

  mkOwnerDefaults = userName: systemUser: {
    user = userName;
    group = if systemUser ? group then systemUser.group else userName;
  };

  mkPersistBase = userName: userCfg:
    normalizePath (
      cfg.persistDir
      + (if userCfg.persistSubdir != null then userCfg.persistSubdir else "/${userName}")
    );

  activeUserConfigs = filterAttrs (_: userCfg: userCfg.enable) combinedUserConfigs;

  resolveMountOptions = custom:
    let
      base = cfg.mountOpts;
    in
    if custom == null then
      base
    else if custom.mode == "append" then
      base ++ custom.options
    else
      custom.options;

  directoryModeFor = entry:
    if entry.origin == "system" then
      systemDirectoryDefaults.mode
    else
      defaultUserDirMode (dirOf entry.relativePath);

  directoryOwnerFor = entry:
    if entry.origin == "system" then
      {
        user = systemDirectoryDefaults.user;
        group = systemDirectoryDefaults.group;
      }
    else
      {
        user = entry.owner.user;
        group = entry.owner.group;
      };

  mkUserDirectoryEntries = userName: userCfg:
    let
      systemUser = requireSystemUser userName;
      ownerDefaults = mkOwnerDefaults userName systemUser;
      persistBase = mkPersistBase userName userCfg;
      location = "users.${userName}.directories";
    in
    map
      (entry:
        let
          ownerUser = if entry.user != null then ensureOverrideUser location entry.user else ownerDefaults.user;
          ownerGroup =
            if entry.group != null then
              ensureOverrideGroup location entry.group
            else if ownerDefaults.group != null then
              ownerDefaults.group
            else
              ownerDefaults.user;
          mode = if entry.mode != null then entry.mode else defaultUserDirMode entry.directory;
          targetPath = joinPath userCfg.home entry.directory;
          persistentPath =
            if entry.persistPathOverride != null then
              normalizePath entry.persistPathOverride
            else
              joinPath persistBase entry.directory;
          mountOptions = resolveMountOptions entry.mountOptions;
        in
        {
          kind = "directory";
          origin = "user";
          user = userName;
          relativePath = entry.directory;
          inherit targetPath persistentPath mountOptions;
          owner = {
            inherit ownerUser ownerGroup;
            user = ownerUser;
            group = ownerGroup;
            mode = mode;
          };
        })
      userCfg.directories;

  mkUserFileEntries = userName: userCfg:
    let
      systemUser = requireSystemUser userName;
      ownerDefaults = mkOwnerDefaults userName systemUser;
      persistBase = mkPersistBase userName userCfg;
      location = "users.${userName}.files";
    in
    map
      (entry:
        let
          ownerUser = if entry.user != null then ensureOverrideUser location entry.user else ownerDefaults.user;
          ownerGroup =
            if entry.group != null then
              ensureOverrideGroup location entry.group
            else if ownerDefaults.group != null then
              ownerDefaults.group
            else
              ownerDefaults.user;
          mode = if entry.mode != null then entry.mode else defaultUserFileMode entry.file;
          targetPath = joinPath userCfg.home entry.file;
          persistentPath =
            if entry.persistPathOverride != null then
              normalizePath entry.persistPathOverride
            else
              joinPath persistBase entry.file;
          mountOptions = resolveMountOptions entry.mountOptions;
        in
        {
          kind = "file";
          origin = "user";
          user = userName;
          relativePath = entry.file;
          inherit targetPath persistentPath mountOptions;
          owner = {
            inherit ownerUser ownerGroup;
            user = ownerUser;
            group = ownerGroup;
            mode = mode;
          };
          linkMethod = entry.linkMethod;
        })
      userCfg.files;

  userDirectoryEntries =
    concatMap
      (userName:
        let userCfg = activeUserConfigs.${userName}; in mkUserDirectoryEntries userName userCfg)
      (attrNames activeUserConfigs);

  userFileEntries =
    concatMap
      (userName:
        let userCfg = activeUserConfigs.${userName}; in mkUserFileEntries userName userCfg)
      (attrNames activeUserConfigs);

  allDirectoryEntries = systemDirectoryEntries ++ userDirectoryEntries;
  allFileEntries = userFileEntries;

  directoryTargetConflicts = findDuplicates (map (entry: entry.targetPath) allDirectoryEntries);
  directoryPersistentConflicts = findDuplicates (map (entry: entry.persistentPath) allDirectoryEntries);
  fileTargetConflicts = findDuplicates (map (entry: entry.targetPath) allFileEntries);
  filePersistentConflicts = findDuplicates (map (entry: entry.persistentPath) allFileEntries);

  _ =
    if directoryTargetConflicts != [ ] then
      throw ''mnemosyne: duplicate directory targets detected: ${concatStringsSep ", " directoryTargetConflicts}''
    else if directoryPersistentConflicts != [ ] then
      throw ''mnemosyne: duplicate directory persistent paths detected: ${concatStringsSep ", " directoryPersistentConflicts}''
    else if fileTargetConflicts != [ ] then
      throw ''mnemosyne: duplicate file targets detected: ${concatStringsSep ", " fileTargetConflicts}''
    else if filePersistentConflicts != [ ] then
      throw ''mnemosyne: duplicate file persistent paths detected: ${concatStringsSep ", " filePersistentConflicts}''
    else
      null;

  persistenceMountDefined = hasAttr persistMountService config.systemd.mounts;

  mkEnsureDir = path: user: group: mode:
    ''install -d -m ${escapeShellArg mode} -o ${escapeShellArg user} -g ${escapeShellArg group} ${escapeShellArg path}'';

  # Emit commands to ensure file parents exist and bind/symlink the persisted file.
  mkFileCommand = entry:
    let
      comment = if entry.origin == "system" then null else "# user: ${entry.user}";
      ownerSpec = "${entry.owner.user}:${entry.owner.group}";
      persistentParent = normalizePath (dirOf entry.persistentPath);
      targetParent = normalizePath (dirOf entry.targetPath);
      parentMode = directoryModeFor entry;
      parentOwner = directoryOwnerFor entry;
      ensurePersistentParent = mkEnsureDir persistentParent entry.owner.user entry.owner.group parentMode;
      ensureTargetParent = mkEnsureDir targetParent parentOwner.user parentOwner.group parentMode;
      ensurePersistentFile = ''
        if [ ! -e ${escapeShellArg entry.persistentPath} ]; then
          touch ${escapeShellArg entry.persistentPath}
        fi
        chown ${escapeShellArg ownerSpec} ${escapeShellArg entry.persistentPath}
        chmod ${escapeShellArg entry.owner.mode} ${escapeShellArg entry.persistentPath}
      '';
      bindCommand = ''
        ${mountFileHelper} ${escapeShellArg entry.targetPath} ${escapeShellArg entry.persistentPath} 0
      '';
      symlinkCommand = ''
        rm -f ${escapeShellArg entry.targetPath}
        ln -s ${escapeShellArg entry.persistentPath} ${escapeShellArg entry.targetPath}
      '';
      finalCommand = if entry.linkMethod == "bind" then bindCommand else symlinkCommand;
      commands = [ comment ensurePersistentParent ensureTargetParent ensurePersistentFile finalCommand ];
    in
    concatStringsSep "\n" (filter (cmd: cmd != null) commands);

  # Runtime script to place persisted files via bind mounts or symlinks.
  filePersistenceScript = pkgs.writeShellScript "mnemosyne-persist-files" ''
    set -euo pipefail
    export PATH=${escapeShellArg (lib.makeBinPath [ pkgs.coreutils pkgs.util-linux pkgs.findutils ])}
    ${concatStringsSep "\n\n" (map mkFileCommand allFileEntries)}
  '';

  # Cleanup commands executed on unit stop to unmount or remove symlinks.
  mkFileCleanupCommand = entry:
    let
      comment = if entry.origin == "system" then null else "# user: ${entry.user}";
      cleanup = if entry.linkMethod == "bind" then
        ''
          if findmnt -rno TARGET --target ${escapeShellArg entry.targetPath} >/dev/null 2>&1; then
            umount ${escapeShellArg entry.targetPath}
          fi
        ''
      else
        ''
          if [ -L ${escapeShellArg entry.targetPath} ]; then
            rm -f ${escapeShellArg entry.targetPath}
          fi
        '';
      commands = [ comment cleanup ];
    in
    concatStringsSep "\n" (filter (cmd: cmd != null) commands);

  fileCleanupScript = pkgs.writeShellScript "mnemosyne-unpersist-files" ''
    set -euo pipefail
    export PATH=${escapeShellArg (lib.makeBinPath [ pkgs.coreutils pkgs.util-linux pkgs.findutils ])}
    ${concatStringsSep "\n\n" (map mkFileCleanupCommand allFileEntries)}
  '';

  mapMkDirCommand = entry:
    let
      comment = if entry.origin == "system" then null else "# user: ${entry.user}";
      mkInstall = path: ''
        if [ ! -d ${escapeShellArg path} ]; then
          echo "mnemosyne: creating directory ${escapeShellArg path}"
        fi
        install -d -m ${escapeShellArg entry.owner.mode} -o ${escapeShellArg entry.owner.user} -g ${escapeShellArg entry.owner.group} ${escapeShellArg path}
      '';
      commands = [ comment (mkInstall entry.persistentPath) (mkInstall entry.targetPath) ];
    in
    concatStringsSep "\n" (filter (cmd: cmd != null) commands);

  directoryCreationCommands = map mapMkDirCommand allDirectoryEntries;

  directoryCreationScript = pkgs.writeShellScript "mnemosyne-create-directories" ''
    set -euo pipefail
    ${concatStringsSep "\n" directoryCreationCommands}
  '';

  mkMounts =
    let
      mkEntry = entry: {
        "${entry.targetPath}" = {
          device = entry.persistentPath;
          fsType = "none";
          options = entry.mountOptions;
          depends = [ persistMountService ];
          noCheck = true;
        };
      };
    in
    entries:
      entries
      |> map mkEntry
      |> mkMerge;
in
{
  # TODO: Add a check to ensure that `cfg.persistDir` is on a persisted volume
  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = persistenceMountDefined;
        message = "mnemosyne: expected systemd mount unit ${persistMountService} to exist for persistDir ${cfg.persistDir}";
      }
    ];
    # We need to run the systemd service very early in the boot process
    # so that the persisted state is available to the system from the
    # start.
    boot.initrd.systemd.enable = mkDefault true;
    # Mount the persisted direcotries to their proper paths.
    fileSystems = mkMounts allDirectoryEntries;
    # Ensure that the necessary paths exist in the persisted state storage.
    boot.initrd.systemd.services.make-source-of-persistent-dirs = {
      wantedBy = [ "initrd-root-device.target" ];
      before = [ "sysroot.mount" ];
      requires = [ persistMountService ];
      after = [ persistMountService ];
      path = [ pkgs.coreutils ];
      serviceConfig.Type = "oneshot";
      unitConfig.DefaultDependencies = false;
      serviceConfig.ExecStart = [ "${directoryCreationScript}" ];
    };
    boot.initrd.postResumeCommands = mkIf (!config.boot.initrd.systemd.enable) (mkAfter "${directoryCreationScript}");
    systemd.services = mkIf (allFileEntries != [ ]) {
      "mnemosyne-persist-files" = {
        description = "Bind or link persisted files into place";
        wantedBy = [ "local-fs.target" ];
        before = [ "local-fs.target" ];
        requires = [ persistMountService ];
        after = [ persistMountService ];
        path = [ pkgs.coreutils pkgs.util-linux ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = [ "${filePersistenceScript}" ];
          ExecStop = [ "${fileCleanupScript}" ];
        };
      };
    };
  };
}
