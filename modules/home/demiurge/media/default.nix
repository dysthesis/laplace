{pkgs, ...}: {
  home.packages = with pkgs; [
    ani-cli
  ];

  imports = [
    ./mpv.nix
    ./ytfzf.nix
    ./yt-dlp.nix
  ];
}
