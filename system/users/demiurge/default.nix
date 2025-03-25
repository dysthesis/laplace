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
          git
          direnv
          brightnessctl
          wl-clipboard
          gnupg
          xsecurelock
          atuin
          unstable.sbctl
          protonvpn-gui
          networkmanagerapplet
          (pkgs.uutils-coreutils.override {prefix = "";})
          inputs.poincare.packages.${system}.default
          (inputs.daedalus.packages.${system}.default.override {
            shell = "${lib.getExe pkgs.configured.fish}";
          })
        ]
        ++ (with pkgs.configured; [
          bemenu
          yambar
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
          mpv
          timewarrior
          xinit
          ghostty
        ])
        ++ (with inputs.babel.packages.${system}; [
          askii
        ]);
    };
  };
}
