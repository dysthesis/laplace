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
  desktop = config.laplace.desktop;
  hostSystem = pkgs.stdenv.hostPlatform.system;
  keys = import ../keys.nix;
  terminal =
    (
      if desktop == null
      then lib.components.foot
      else desktop.term
    ).build {
      inherit pkgs lib;
      foot = pkgs.configured.foot;
    };
in {
  config = mkIf cfg {
    environment.shells = lib.optionals isDesktop [
      config.users.users.demiurge.shell
      (lib.getExe pkgs.configured.fish)
    ];

    users.users.demiurge = {
      description = "Demiurge";
      ariadne = isDesktop;
      shell =
        if isDesktop
        then "${pkgs.configured.bash}/bin/bash"
        else pkgs.bash;

      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        keys.phobos
        keys.deimos
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
          configured.helix

          inputs.oh-my-pi.packages.${hostSystem}.default
        ];

        dev = with pkgs; [
          git
          configured.direnv
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
            configured.ytsub
          ]
          ++ lib.optionals (config.laplace.wm != null && config.laplace.wm.protocol == "wayland") [
            wl-clipboard
            grim
            slurp
            swappy
            configured.bibata-hyprcursor
            configured.bemenu
            terminal.package
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
