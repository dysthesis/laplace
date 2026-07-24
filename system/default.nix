{
  inputs,
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib.laplace.modules) importInDirectory;
  system = pkgs.stdenv.hostPlatform.system;
  isDesktop = builtins.elem "desktop" config.laplace.profiles;
in {
  config = {
    environment.sessionVariables =
      {
        GH_TELEMETRY = "false";
        DO_NOT_TRACK = "true";
        # Servers use Vim to avoid pulling the desktop Neovim closure.
        EDITOR = lib.getExe (
          if isDesktop
          then inputs.poincare.packages.${system}.default
          else pkgs.vim
        );
      }
      // lib.optionalAttrs isDesktop {
        BROWSER = lib.getExe pkgs.configured.zen;
      };
    boot.binfmt.emulatedSystems =
      if (system != "aarch64-linux")
      then ["aarch64-linux"]
      else [];
    boot.zfs.forceImportRoot = false;
    environment.systemPackages = with pkgs; [
      pam_u2f
    ];

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
      pcscd.enable = true;
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
      ccache.enable = true;
    };

    nix.settings.extra-sandbox-paths = [config.programs.ccache.cacheDir];
  };
  imports = importInDirectory ./.;
}
