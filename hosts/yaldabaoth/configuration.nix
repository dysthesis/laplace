{
  config,
  pkgs,
  ...
}: {
  config = {
    # CCache stuff
    programs.ccache = {
      enable = true;
    };
    nixpkgs.overlays = [
      (_self: super: {
        ccacheWrapper = super.ccacheWrapper.override {
          extraConfig = ''
            export CCACHE_COMPRESS=1
            export CCACHE_DIR="${config.programs.ccache.cacheDir}"
            export CCACHE_UMASK=007
            if [ ! -d "$CCACHE_DIR" ]; then
              echo "====="
              echo "Directory '$CCACHE_DIR' does not exist"
              echo "Please create it with:"
              echo "  sudo mkdir -m0770 '$CCACHE_DIR'"
              echo "  sudo chown root:nixbld '$CCACHE_DIR'"
              echo "====="
              exit 1
            fi
            if [ ! -w "$CCACHE_DIR" ]; then
              echo "====="
              echo "Directory '$CCACHE_DIR' is not accessible for user $(whoami)"
              echo "Please verify its access permissions"
              echo "====="
              exit 1
            fi
          '';
        };
      })
    ];
    nix.settings.extra-sandbox-paths = [config.programs.ccache.cacheDir];

    programs.nix-ld.enable = true;
    services.fstrim.enable = true;
    programs.java.enable = true;
    security = {
      # For electron stuff
      chromiumSuidSandbox.enable = true;

      # `login` means TTY login
      pam.services.login.enableGnomeKeyring = true;
    };

    environment.loginShellInit =
      /*
      sh
      */
      ''
        eval $(gnome-keyring-daemon --daemonize)
      '';
    # The 6.6.31 hardened kernel prevents NixOS from shutting down or rebooting in the kernel
    # and I have no idea how to pin hardened kernels, so...
    boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;
    boot.binfmt.emulatedSystems = ["aarch64-linux"];

    laplace = {
      hardware = {
        cpu = "amd";
        gpu = "amd";
        monitors = [
          {
            name = "eDP";
            width = 2256;
            height = 1504;
            refreshRate = 60;
            pos = {
              x = 0;
              y = 0;
            };
          }
        ];
      };

      bootloader = "systemd-boot";

      network = {
        bluetooth.enable = true;
        wifi.enable = true;
        dnscrypt-proxy.enable = true;
      };

      security = {
        privesc = "doas";
        apparmor.enable = true;
        polkit.enable = true;
        secure-boot.enable = true;
        firewall.enable = true;
      };

      sound = {
        enable = true;
        server = "pipewire";
      };

      users.demiurge = {
        enable = true;
        useHomeManager = true;
      };

      features = {
        podman.enable = true;
        nh = {
          enable = true;
          flakePath = "/home/demiurge/Documents/Projects/laplace";
        };

        restic = {
          enable = true;
          paths = ["/nix/persist"];
          targets = ["b2:yaldabaoth"];
        };

        impermanence.enable = true;
        virtualisation.enable = true;

        hardening = {
          kernel.enable = true;
          malloc.enable = false; # Scudo breaks firefox?
        };

        displayServer = "wayland";
        ssh.enable = true;

        docs.enable = false;
      };
    };

    time.timeZone = "Australia/Sydney";
    i18n.defaultLocale = "en_AU.UTF-8";

    console = {
      earlySetup = true;
      font = "${pkgs.terminus_font}/share/consolefonts/ter-120n.psf.gz";
    };

    system.stateVersion = "24.11";
  };
}
