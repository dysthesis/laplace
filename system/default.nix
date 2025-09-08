{
  inputs,
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib.babel.modules) importInDirectory;
in {
  config = {
    environment.sessionVariables = {
      BROWSER = lib.getExe pkgs.configured.zen;
      EDITOR = lib.getExe inputs.poincare.packages.${pkgs.system}.default;
    };
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
      ports = [
        22
        12345 # calibre
      ];
    };
    console = {
      earlySetup = true;
      font = lib.mkIf (builtins.elem "desktop" config.laplace.profiles) "${pkgs.terminus_font}/share/consolefonts/ter-120n.psf.gz";
    };

    system.stateVersion = "24.11";

    time.timeZone = "Australia/Sydney";
    i18n.defaultLocale = "en_AU.UTF-8";
    hardware.enableRedistributableFirmware = true;
    programs.nix-ld = {
      enable = true;
      libraries = with pkgs; [
        stdenv.cc.cc.lib
        glibc
        zlib
      ];
    };
  };
  imports = importInDirectory ./.;
}
