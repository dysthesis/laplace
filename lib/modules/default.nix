lib: {
  fromDirectories = import ./fromDirectories.nix lib;
  toEnableOptions = import ./toEnableOptions.nix lib;
  enableOptsFromDir = import ./enableOptsFromDir.nix lib;
  importInDirectory = import ./importInDirectory.nix lib;
}
