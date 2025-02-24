{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: let
  inherit
    (pkgs)
    system
    ;

  inherit
    (lib)
    mkIf
    ;
  inherit
    (builtins)
    elem
    filter
    hasAttr
    ;

  cfg = elem "demiurge" config.laplace.users;
  ifTheyExist = groups: filter (group: hasAttr group config.users.groups) groups;
in {
  config = mkIf cfg {
    users.users.demiurge = {
      description = "Demiurge";
      shell = "${pkgs.configured.bash}/bin/bash";
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF4Rfg1TJZb861LSAJZn1xKNO1PXf7Oz2Mucq//9Dr9s demiurge@phobos"
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
      packages = with pkgs;
        [
          signal-desktop
          btop
          microfetch
          git
          direnv
          brightnessctl
          xclip
          gnupg
          xsecurelock
          atuin
        ]
        ++ (with pkgs.configured; [
          fish
          bash
          ytfzf
          zathura
          ani-cli
          spotify-player
          zen
          vesktop
          taskwarrior
          taskwarrior-tui
          weechat
        ])
        ++ [
          inputs.poincare.packages.${system}.default
          inputs.daedalus.packages.${system}.default
        ]
        ++ (
          with inputs.gungnir.packages.${system}; let
            fontSize =
              if config.networking.hostName == "phobos"
              then 15
              else 12;
          in [
            (st {inherit fontSize;})
            (dmenu {inherit fontSize;})
          ]
        );
    };
  };
}
