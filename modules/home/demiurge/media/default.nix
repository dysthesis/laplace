{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    (ani-cli.override {
      mpv = mpv.override {
        scripts = config.programs.mpv.scripts;
      };
    })
  ];

  imports = [
    ./mpv.nix
    ./ytfzf.nix
    ./yt-dlp.nix
  ];
}
