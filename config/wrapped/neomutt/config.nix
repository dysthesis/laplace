{pkgs, ...}:
pkgs.writeTextFile {
  name = "neomutt-config";
  text = ''
    set realname = "Antheo Raviel"
    set from = "z5437039@ad.unsw.edu.au"
    set use_from = yes
    set envelope_from = yes

    set smtp_url = "smtp://z5437039@ad.unsw.edu.au@smtp.office365.com:587"
    set imap_user = "z5437039@ad.unsw.edu.au"
    set folder = "imaps://z5437039@ad.unsw.edu.au@outlook.office365.com:993"
    set spoolfile = "+INBOX"
    set ssl_force_tls = yes
    set ssl_starttls = yes

    # G to get mail
    bind index G imap-fetch-mail
    set editor = "nvim"
    set charset = "utf-8"
    set record = "+Sent"
    set imap_authenticators="oauthbearer:xoauth2"
    set imap_oauth_refresh_command="~/.local/scripts/mutt_oauth2.py ~/.local/share/unsw.token"
    set smtp_authenticators="oauthbearer:xoauth2"
    set smtp_oauth_refresh_command="~/.local/scripts/mutt_oauth2.py ~/.local/share/unsw.token"

    # change the sorting to go by date of arrival and have the most recent mail at the top:
    set sort=reverse-date-received

    # disable the help display
    set help = no

    # move the status bar to the top
    set status_on_top = yes

    # and show some useful status information there
    set status_format = "  %u %?p?  %p&?%?F?   %F&? %>  %m "

    set index_format  = "%4C %?X?& ?%S %.70s %> %L %D"
    set flag_chars    = "d  "
  '';
}
