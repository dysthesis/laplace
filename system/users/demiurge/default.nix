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
  ifTheyExist = groups: filter (group: hasAttr group config.users.groups) groups;
in {
  config = mkIf cfg {
    users.users.demiurge = {
      description = "Demiurge";
      shell = pkgs.bash;
      isNormalUser = true;
      openssh.authorizedKeys.keys = [];
      hashedPassword = "$y$j9T$zvO0pMcCC7uiQswzHEPri/$VRaKlhJWajtyRvnQwy1CNQE7BX8Kp8MigiBqPhK8zrD";
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
      packages = with inputs.gungnir.packages.${pkgs.system}; [
        inputs.poincare.packages.${pkgs.system}.default
        inputs.daedalus.packages.${pkgs.system}.default
        inputs.zen-browser.packages.${pkgs.system}.default
        dwm
        st
        dmenu
      ];
    };
  };
}
