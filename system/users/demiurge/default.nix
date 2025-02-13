{
  self,
  inputs,
  lib,
  config,
  pkgs,
  ...
}: let
  inherit
    (pkgs)
    writeText
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

  wm = inputs.gungnir.packages.${system}.dwm;
  wallpaper = ../.../../../assets/wallpaper.png;

  xinitrc = with pkgs;
    writeText ".xinitrc"
    # sh
    ''
      # turn off Display Power Management Service (DPMS)
      xset -dpms
      setterm -blank 0 -powerdown 0

      # turn off black Screensaver
      xset s off

      # Start some services
      ${dunst} &
      ${udiskie} &
      ${hsetroot} ${wallpaper} &
      ${inputs.gungnir.packages.${system}.dwm-bar} &
      exec ${wm}
    '';

  xinit-dwm = pkgs.stdenv.mkDerivation rec {
    name = "xinit-dwm";
    buildInputs = with pkgs; [
      makeWrapper
      xorg.xinit
    ];
    installPhase =
      # sh
      ''
        makeWrapper ${lib.getExe pkgs.xorg.xinit} $out/bin/${name} \
        	--add-flags ${xinitrc}
      '';
  };

  cfg = elem "demiurge" config.laplace.users;
  ifTheyExist = groups: filter (group: hasAttr group config.users.groups) groups;
in {
  config = mkIf cfg {
    users.users.demiurge = {
      description = "Demiurge";
      shell = pkgs.bash;
      isNormalUser = true;
      openssh.authorizedKeys.keys = [];
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
        ]
        ++ [
          inputs.poincare.packages.${system}.default
          inputs.daedalus.packages.${system}.default
          inputs.zen-browser.packages.${system}.default
          xinit-dwm
        ]
        ++ (with inputs.gungnir.packages.${system}; [
          st
          dmenu
          signal-desktop
        ]);
    };
  };
}
