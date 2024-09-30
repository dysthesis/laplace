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

  cfg = config.laplace.users.abraxas.enable;
  ifTheyExist = groups:
    filter
    (group: hasAttr group config.users.groups)
    groups;
in {
  config = let
    shell = "zsh";
  in
    mkIf cfg {
      users.users.abraxas = {
        description = "Abraxas";
        isNormalUser = true;
        shell = pkgs.${shell};

        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOOeZRCxL7/q0UY7ZAAkM5HW6t8RULHu1b7BH3F/n2d2 demiurge@yaldabaoth"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFN0bzRvuz3JfjOXTtgB5CTC9me7bnCTbudpkBVqkYMN demiurge@adonaios"
        ];

        # TODO: Add hashed password with sops-nix
        hashedPasswordFile = config.sops.secrets."hashedPasswords/abraxas".path;

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
