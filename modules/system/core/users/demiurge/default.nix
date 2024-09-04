{
  lib,
  config,
  pkgs,
  ...
}: let
  inherit
    (lib)
    mkIf
    ;
  inherit
    (builtins)
    filter
    hasAttr
    ;

  cfg = config.laplace.users.demiurge.enable;
  ifTheyExist = groups:
    filter
    (group: hasAttr group config.users.groups)
    groups;
in {
  config = let
    shell = "zsh";
  in
    mkIf cfg {
      users.users.demiurge = {
        description = "Demiurge";
        isNormalUser = true;
        shell = pkgs.${shell};

        hashedPasswordFile = config.sops.secrets."hashedPasswords/demiurge".path;

        extraGroups =
          [
            "wheel"
            "video"
            "audio"
            "input"
            "nix"
            "networkmanager"
          ]
          ++ ifTheyExist [
            "network"
            "docker"
            "podman"
            "libvirt"
          ];
      };
      programs.${shell}.enable = true;
    };
}
