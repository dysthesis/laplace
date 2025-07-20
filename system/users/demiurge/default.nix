{
  inputs,
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
          inputs.poincare.packages.${pkgs.system}.default
          age
          sops
        ];

        cli = with pkgs; [
          (uutils-coreutils.override {prefix = "";})
          bat
        ];

        dev = with pkgs; [
          git
          direnv
          configured.jujutsu
          inputs.poincare.packages.${pkgs.system}.default
          (inputs.daedalus.packages.${pkgs.system}.default.override {
            shell = "${pkgs.configured.fish}/bin/fish";
            targets = [
              "~/Documents/Projects/"
              "~/Documents/University/"
            ];
          })
        ];

        desktop = with pkgs; [
          brightnessctl
          wl-clipboard
          grim
          slurp
          swappy
          yambar
          bash
          configured.bibata-hyprcursor
          configured.bemenu
          configured.ghostty
        ];

        applications = with pkgs; [
          unstable.zotero
          signal-desktop
          prismlauncher
          tor-browser-bundle-bin
        ];

        system = with pkgs; [
          unstable.sbctl
        ];

        apps = with pkgs.configured; [
          zathura
          spotify-player
          zen
          vesktop
          irssi
          mpv
          neomutt
        ];

        productivity = with pkgs.configured; [
          read
          newsraft
          taskwarrior
          timewarrior
          taskwarrior-tui
          zk
          pass
        ];

        misc = with pkgs.configured; [
          btop
          ytfzf
          ani-cli
        ];

        desktopPackages = cli ++ dev ++ desktop ++ applications ++ system ++ misc ++ apps ++ productivity;

        addIf = cond: content:
          if cond
          then content
          else [];
      in
        basePackages ++ addIf isDesktop desktopPackages;
    };
  };
}
