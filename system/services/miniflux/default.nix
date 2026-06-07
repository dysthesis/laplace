{lib, ...}: {
  imports = [./config.nix];

  options.laplace.services.miniflux.enable =
    lib.mkEnableOption "Whether or not to enable the Miniflux RSS feed reader";
}
