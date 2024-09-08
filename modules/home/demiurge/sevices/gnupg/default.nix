{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) fold toLower;
in {
  programs.gpg.enable = true;
  services.gpg-agent =
    {
      enable = true;
      pinentryPackage = pkgs.pinentry-gnome3;
      enableSshSupport = true;
      maxCacheTtl = 1800;
      defaultCacheTtl = 300;
      extraConfig = ''
        no-allow-external-cache
      '';
    } # Automatically enable integration with any enabled shells
    // fold
    (curr: acc:
      acc
      // {"enable${curr}Integration" = config.programs.${toLower curr}.enable;})
    {}
    ["Zsh" "Bash" "Fish"];
}
