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
        addIf = cond: content:
          if cond
          then content
          else [];

        basePackages = with pkgs; [
          rsync
          gnupg
          inputs.poincare.packages.${pkgs.system}.default
          age
          sops
        ];

        cli = with pkgs; [
          unstable.uutils-coreutils-noprefix
          unstable.bat
          unstable.tealdeer
          unstable.gh
          configured.bibiman
          # configured.wikiman
          (unstable.openai-whisper.override {triton = null;})
          # (mkWrapper pkgs (unstable.openai-whisper.override {triton = null;})
          #   #sh
          #   ''
          #     wrapProgram "$out/bin/whisper" \
          #       --set PYTORCH_ROCM_ARCH  "gfx1030" \
          #       --set HSA_OVERRIDE_GFX_VERSION "10.3.0" \
          #       --set HCC_AMDGPU_TARGET "gfx1030"
          #   '')
          configured.bmm
          configured.helix
        ];

        dev = with pkgs; [
          git
          direnv
          configured.jujutsu
          unstable.texliveFull
          inputs.poincare.packages.${pkgs.system}.default
          (inputs.daedalus.packages.${pkgs.system}.default.override {
            shell = "${pkgs.configured.fish}/bin/fish";
            targets = [
              "~/Documents/Projects/"
              "~/Documents/University/"
            ];
          })
        ];

        desktop = with pkgs;
          [
            brightnessctl
            bash
            calibre
            bibata-cursors
          ]
          ++ addIf (builtins.elem "wayland" config.laplace.display.servers) [
            wl-clipboard
            grim
            slurp
            swappy
            configured.bibata-hyprcursor
            configured.bemenu
            configured.ghostty
            configured.wezterm
          ]
          ++ addIf (builtins.elem "xorg" config.laplace.display.servers) (
            with inputs.gungnir.packages.${pkgs.system}; let
              fontSize =
                if config.networking.hostName == "phobos"
                then 15
                else 12;
            in [
              xsecurelock
              xclip
              (st {
                inherit fontSize;
                borderpx = 20;
                shell = lib.getExe pkgs.configured.fish;
              })
              (dmenu {
                inherit fontSize;
                lineHeight = 26;
              })
            ]
          );

        applications = with pkgs; [
          inputs.jormungandr.packages.${pkgs.system}.default
          unstable.zotero
          signal-desktop
          prismlauncher
          unstable.tor-browser
          tigervnc
          obsidian
        ];

        system = with pkgs; [
          unstable.sbctl
          wireguard-tools
        ];

        apps = with pkgs.configured;
          [
            zathura
            spotify-player
            irssi
            mpv
            neomutt
          ]
          ++ (with pkgs.unstable; [
            vesktop
            inputs.zen-browser.packages."${pkgs.system}".default
          ]);

        productivity = with pkgs.configured; [
          # read
          newsraft
          taskwarrior
          timewarrior
          taskwarrior-tui
          zk
          pass
        ];

        misc = let
          hindsight = pkgs.rustPlatform.buildRustPackage rec {
            pname = "hindsight";
            version = "efbabf48603fd4f9cbff44e4057a2eb648c71094";
            src = pkgs.fetchFromGitHub {
              owner = "chaosprint";
              repo = "hindsight";
              rev = version;
              sha256 = "sha256-8KfiPfrWf9ioA2+6gF1PSQi6ED0Grh+H5jZGTEg4m5c=";
            };
            cargoHash = "sha256-lLN+QswPrdY19yW4w9jPA+6ebqvcOa80bY3B1nuxdIw=";

            nativeBuildInputs = with pkgs; [
              pkg-config
              openssl
            ];
            buildInputs = with pkgs; [
              cacert
              pkg-config
              openssl
            ];
          };
        in
          with pkgs.configured;
            [
              btop
              ytfzf
              ani-cli
              hindsight
            ]
            ++ (with pkgs.unstable; [yt-dlp]);

        desktopPackages =
          cli ++ dev ++ desktop ++ applications ++ system ++ misc ++ apps ++ productivity;
      in
        basePackages ++ addIf isDesktop desktopPackages;
    };
  };
}
