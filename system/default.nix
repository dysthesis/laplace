{
  inputs,
  pkgs,
  lib,
  config,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
  isDesktop = builtins.elem "desktop" config.laplace.profiles;
in {
  config = {
    environment.sessionVariables =
      {
        GH_TELEMETRY = "false";
        DO_NOT_TRACK = "true";
        # Servers use Vim to exclude the desktop Neovim closure.
        EDITOR = lib.getExe (
          if isDesktop
          then inputs.poincare.packages.${system}.default
          else pkgs.vim
        );
      }
      // lib.optionalAttrs isDesktop {
        BROWSER = lib.getExe pkgs.configured.zen;
      };

    boot.zfs.forceImportRoot = false;

    services = {
      openssh = {
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
        ];
      };
    };
    console = {
      earlySetup = true;
      font = lib.mkIf (builtins.elem "desktop" config.laplace.profiles) "${pkgs.terminus_font}/share/consolefonts/ter-120n.psf.gz";
    };

    system.stateVersion = "24.11";

    time.timeZone = lib.mkDefault "Australia/Sydney";
    i18n.defaultLocale = "en_AU.UTF-8";
    hardware.enableRedistributableFirmware = true;
    programs = {
      nix-ld = {
        enable = true;
        libraries = with pkgs; [
          stdenv.cc.cc.lib
          glibc
          zlib
        ];
      };
    };
  };
  imports = [
    ./boot
    ./display
    ./docker
    ./filesystems
    ./hardening
    ./hardware
    ./network
    ./nh
    ./nix
    ./profiles
    ./secrets
    ./security
    ./services
    ./sound
    ./tailnet
    ./users
    ./virtualisation
    ./zram
  ];
}
