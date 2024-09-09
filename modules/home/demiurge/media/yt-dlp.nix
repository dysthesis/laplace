{
  programs.yt-dlp = {
    enable = true;
    settings = {
      embed-thumbnail = true;
      embed-subs = true;
      embed-metadata = true;
      sub-langs = "en.*";
      sponsorblock-remove = "sponsor,selfpromo,interaction,intro,outro,preview,music_offtopic";
    };
  };
}
