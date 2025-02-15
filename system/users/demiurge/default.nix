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
          btop
          noto-fonts
          noto-fonts-extra
          noto-fonts-emoji
          noto-fonts-cjk-sans
        ]
        ++ [
          inputs.poincare.packages.${system}.default
          inputs.daedalus.packages.${system}.default
          inputs.zen-browser.packages.${system}.default
        ]
        ++ (with inputs.gungnir.packages.${system}; [
          st
          dmenu
          dwm
        ])
        ++ (with inputs.babel.packages.${pkgs}; [
          jbcustom-nf
        ]);
    };
  };
}
