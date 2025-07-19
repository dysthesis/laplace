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
  ifExists = groups: filter (group: hasAttr group config.users.groups) groups;
  isDesktop = elem "desktop" config.laplace.profiles;
in {
  config = mkIf cfg {
    users.users.demiurge = {
      description = "Demiurge";
      shell =
        if isDesktop
        then "${pkgs.configured.bash}/bin/bash"
        else pkgs.bash;

      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF4Rfg1TJZb861LSAJZn1xKNO1PXf7Oz2Mucq//9Dr9s demiurge@phobos"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDUPaVrhCJ8fDKDYCcIeICgCv6W+0GdGmMDrngIg1oKg demiurge@deimos"
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
        ++ ifExists [
          "network"
          "docker"
          "podman"
          "libvirt"
          "render"
          "ollama"
        ];

      packages = let
        basePackages = with pkgs; [
          rsync
          gnupg
          configured.helix
        ];

        desktopPackages = with pkgs;
          [
            (uutils-coreutils.override {prefix = "";})
            unstable.zotero
            swaylock
            signal-desktop
            git
            direnv
            brightnessctl
            prismlauncher
            wl-clipboard
            unstable.sbctl
            tor-browser-bundle-bin
            inputs.poincare.packages.${system}.default
            (inputs.daedalus.packages.${system}.default.override {
              shell = "${pkgs.configured.fish}/bin/fish";
              targets = [
                "~/Documents/Projects/"
                "~/Documents/University/"
              ];
            })
            grim
            slurp
            swappy
            bat
          ]
          ++ (with pkgs.configured; [
            read
            btop
            newsraft
            bemenu
            yambar
            bash
            ytfzf
            zathura
            ani-cli
            spotify-player
            zen
            vesktop
            taskwarrior
            irssi
            mpv
            timewarrior
            ghostty
            zk
            taskwarrior-tui
            neomutt
            jujutsu
            pass
            bibata-hyprcursor
          ]);

        addIf = cond: content:
          if cond
          then content
          else [];
      in
        basePackages ++ addIf isDesktop desktopPackages;
    };
  };
}
