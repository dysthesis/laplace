{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib.babel.modules) importInDirectory;
  inherit (lib) getExe;
in {
  config = {
    boot.binfmt.emulatedSystems =
      if (config.nixpkgs.system != "aarch64-linux")
      then ["aarch64-linux"]
      else [];
    services.openssh = {
      enable = lib.mkDefault true;
      settings = {
        PermitRootLogin = lib.mkForce "no";
        UseDns = false;
        X11Forwarding = false;
        PasswordAuthentication = lib.mkForce false;
        KbdInteractiveAuthentication = false;
      };
      openFirewall = true;
      ports = [22];
    };
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
