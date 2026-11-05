{pkgs}: let
  inherit (pkgs) lib;
  terminal = import ../../user/wrapped/foot/operations.nix {
    inherit pkgs lib;
    foot = pkgs.configured.foot;
  };
in
  pkgs.writeText "terminal-helpers-manifest.json" (builtins.toJSON {
    inherit (terminal) launch appId execute executeWithAppId;
    capture = lib.getExe pkgs.scripts.zk-capture;
    journal = lib.getExe pkgs.scripts.zk-journal;
    git = lib.getExe pkgs.git;
    nvim = lib.getExe pkgs.neovim;
    path = lib.makeBinPath [pkgs.coreutils pkgs.git pkgs.zk pkgs.neovim];
  })
