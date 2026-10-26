{lib, ...}: {
  imports = [./config.nix];
  options.laplace.services.music =
    {
      enable = lib.mkEnableOption "the shared music automation pipeline";
    }
    // import ./settings.nix {inherit lib;};
}
