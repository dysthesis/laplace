{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    (ani-cli.override {
      mpv = mpv.override {
        inherit (config.programs.mpv) scripts;
      };
    })
  ];

  imports = [
    ./mpv.nix
    ./ytfzf.nix
    ./yt-dlp.nix
  ];
}
