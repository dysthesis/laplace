{
  pkgs,
  lib,
  ...
}: let
  inherit (lib.babel.modules) importInDirectory;
in {
  config = {
    console = {
      earlySetup = true;
      font = "${pkgs.terminus_font}/share/consolefonts/ter-120n.psf.gz";
    };

    system.stateVersion = "24.11";

    time.timeZone = "Australia/Sydney";
    i18n.defaultLocale = "en_AU.UTF-8";
  };
  imports = importInDirectory ./.;
}
