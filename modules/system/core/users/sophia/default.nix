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

  cfg = config.laplace.users.sophia.enable;
  ifTheyExist = groups:
    filter
    (group: hasAttr group config.users.groups)
    groups;
in {
  config = let
    shell = "zsh";
  in
    mkIf cfg {
      users.users.sophia = {
        description = "Sophia";
        isNormalUser = true;
        shell = pkgs.${shell};

        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJaEjA5EWVunY9YZkHY0HIGYlEyze/hqJkrarxFvDpiI demiurge@noesis"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOOeZRCxL7/q0UY7ZAAkM5HW6t8RULHu1b7BH3F/n2d2 demiurge@yaldabaoth"
        ];

        # TODO: Add hashed password with sops-nix
        hashedPassword = "$y$j9T$DwXQ1sFrJsV/zUYywaypt/$caKzg2x8CDiWTG.DQTkIZw7Y7AY8REXnwzNwDqFHEt5";

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
