{pkgs, ...}: {
  home.packages = with pkgs; [
    ani-cli
  ];

  imports = [./mpv.nix];
}
