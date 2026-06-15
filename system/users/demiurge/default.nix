{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  inherit (lib.laplace.pkgs) mkWrapper;
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
        ];

        dev = with pkgs; [
          git
          direnv
          configured.jujutsu
          configured.jjui
          configured.tmux
          unstable.texliveFull
          inputs.poincare.packages.${hostSystem}.default
        ];

        desktop = with pkgs;
          [
            brightnessctl
            bash
            calibre
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
        # xorg session packages (gungnir's st/dmenu/xsecurelock) moved to
        # system/display/servers/xorg/sessions/xmonad.

        applications = with pkgs; [
          zotero
          signal-desktop
          (unstable.prismlauncher.override {
            jdks = with pkgs; [zulu25 jdk21 jdk17 jdk8];
          })
          unstable.tor-browser
          tigervnc
          (mkWrapper pkgs.unstable pkgs.unstable.obsidian ''
            wrapProgram $out/bin/obsidian \
            --prefix PATH : ${lib.makeBinPath (with pkgs.unstable; [
              claude-code
            ])} '')
          unstable.claude-code
        ];

        system = with pkgs; [
          unstable.sbctl
          wireguard-tools
        ];

        apps = with pkgs.configured;
          [
            zathura
            spotify-player
            mpv
            neomutt
          ]
          ++ (with pkgs.unstable; [
            vesktop
            zen
            # todoist-electron
          ]);

        productivity = with pkgs.configured; [
          # read
          newsraft
          taskwarrior
          timewarrior
          taskwarrior-tui
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
