{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  inherit (builtins) elem;
  cfg = config.laplace.display;
  enabled = elem "xorg" cfg.servers && cfg.xorg.session == "xmonad";
  hostSystem = pkgs.stdenv.hostPlatform.system;
  # If broken, gate this payload too; its values are forced before selector assertions.
in {
  config = lib.mkIf enabled {
    laplace.display.xorg.sessionCommand = "${pkgs.configured.xinit}/bin/startx";

    users.users = lib.mkIf (elem "demiurge" config.laplace.users) {
      demiurge.packages = let
        inherit (inputs.gungnir.packages.${hostSystem}) st dmenu;
        fontSize =
          if config.networking.hostName == "phobos"
          then 15
          else 12;
      in [
        pkgs.xsecurelock
        pkgs.xclip
        (st {
          inherit fontSize;
          borderpx = 20;
          shell = lib.getExe pkgs.configured.fish;
        })
        (dmenu {
          inherit fontSize;
          lineHeight = 26;
        })
      ];
    };
  };
}
