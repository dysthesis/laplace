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
  # The pinned gungnir and mandelbrot revisions cannot evaluate (see the
  # broken entry in ../../default.nix; fixes exist in their local checkouts
  # and verified end-to-end, pending push + `nix flake update`). Anything
  # this module contributes gets forced during config evaluation
  # (users-groups forces package lists while collecting assertions; the
  # bash wrapper forces sessionCommand), which would preempt the selector's
  # broken-member assertion with an opaque eval error — so the payload stays
  # inert until the inputs are updated. Flip this together with removing
  # the `broken` entry.
  worksUpstream = false;
in {
  config = lib.mkIf (enabled && worksUpstream) {
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
