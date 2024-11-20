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
    shell = "bash";
  in
    mkIf cfg {
      users.users.demiurge = {
        description = "Demiurge";
        isNormalUser = true;
        shell = pkgs.${shell};
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPxBpd1Xyr16hfHFvd/AvOz8mLehUCI28QW3WNht4Xkn demiurge@adonaios"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOOeZRCxL7/q0UY7ZAAkM5HW6t8RULHu1b7BH3F/n2d2 demiurge@yaldabaoth"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJazHjq2dgnKO3SmC2Z6mfoVk4cmdk0digem0bLZSYHF demiurge@erebus"
        ];
        hashedPassword = "$y$j9T$WtVEPLB064z6W2eWFUPK81$xT7V9MzUIS.gcoaJzfYjMRY/I5Zi5Hl57XDo9EMwll5";
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
    };
}
