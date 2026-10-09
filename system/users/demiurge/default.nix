{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  inherit (builtins) elem filter hasAttr;
  cfg = elem "demiurge" config.laplace.users;
  ifExists = groups: filter (group: hasAttr group config.users.groups) groups;
  isDesktop = elem "desktop" config.laplace.profiles;
  hostSystem = pkgs.stdenv.hostPlatform.system;
in {
  config = mkIf cfg {
    users.users.demiurge = {
      description = "Demiurge";
      ariadne = isDesktop;
      shell =
        if isDesktop
        then "${pkgs.configured.bash}/bin/bash"
        else pkgs.bash;

      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJoKu8wF8Ts5xlCcKBQ8zRU7A4NsujnhzfsGfaP62kf2 demiurge@phobos"
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
          "adbusers"
          "i2c"
        ];

      packages = let
        basePackages = with pkgs; [
          rsync
          gnupg
          inputs.poincare.packages.${hostSystem}.default

          age
          sops
        ];

        cli = with pkgs; [
          unstable.bat
          unstable.tealdeer
          unstable.gh
          configured.bibiman
          configured.bmm
          configured.helix
          configured.opencode
          inputs.oh-my-pi.packages.${hostSystem}.default
          unstable.pi-coding-agent
        ];

        dev = with pkgs; [
          git
          direnv
          configured.jujutsu
          configured.headroom
          configured.jjui
          configured.tmux
          unstable.texliveFull
        ];

        desktop = with pkgs;
          [
            brightnessctl
            bash
            calibre-no-speech
            bibata-cursors
            pwvucontrol
          ]
          ++ lib.optionals (builtins.elem "wayland" config.laplace.display.servers) [
            wl-clipboard
            grim
            slurp
            swappy
            configured.bibata-hyprcursor
            configured.bemenu
            configured.foot
          ];
        applications = with pkgs; [
          unstable.signal-desktop
          unstable.obsidian
          unstable.zotero
          configured.subtui
          (unstable.prismlauncher.override {
            jdks = with pkgs; [
              graalvmPackages.graalvm-oracle_17
              zulu25
              jdk21
              jdk17
              jdk8
            ];
            gamemodeSupport = true;
          })
          tigervnc
        ];

        system = with pkgs; [
          unstable.sbctl
          wireguard-tools
        ];

        apps = with pkgs.configured; [
          zathura
          mpv
          neomutt
          vesktop
          zen
        ];

        productivity = with pkgs.configured; [
          newsraft
          taskwarrior
          timewarrior
          taskwarrior-tui2
          khal
          vdirsyncer
          zk
          pass
          gh-dash
        ];

        misc = with pkgs.configured;
          [
            btop
            ytfzf
            ani-cli
          ]
          ++ (with pkgs.unstable; [yt-dlp]);

        desktopPackages =
          cli ++ dev ++ desktop ++ applications ++ system ++ misc ++ apps ++ productivity;
      in
        basePackages ++ lib.optionals isDesktop desktopPackages;
    };
  };
}
