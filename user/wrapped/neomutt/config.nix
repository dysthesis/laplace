{
  pkgs,
  lib,
  ...
}: let
  mailcap = import ./mailcap.nix {inherit pkgs lib;};
in
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
      set ssl_force_tls = yes
      set ssl_starttls = yes

      set spoolfile = "+INBOX"
      set postponed = "+Drafts"
      set record = "+Sent Items"
      set trash = "+Deleted Items"

      set header_cache = "$HOME/.cache/mutt/headers"
      set message_cachedir = "$HOME/.cache/mutt/bodies"
      set certificate_file = "$HOME/.cache/mutt/certificates"
      unset record

      set editor = "nvim"
      set charset = "utf-8"
      set imap_authenticators="oauthbearer:xoauth2"
      set imap_oauth_refresh_command="~/.local/scripts/mutt_oauth2.py ~/.local/share/unsw.token"
      set smtp_authenticators=''${imap_authenticators}
      set smtp_oauth_refresh_command=''${imap_oauth_refresh_command}

      set pager_index_lines = 10
      set pager_context = 3
      set pager_stop
      set menu_scroll
      set tilde        # Fill short pages with ~.
      set move=no      # Keep read messages in the same mailbox.
      set mail_check = 30
      set imap_keepalive = 900 # 15 minutes
      set sleep_time = 0
      set wait_key = no # Disable the "press key to continue" prompt.
      set envelope_from
      set edit_headers
      set fast_reply   # Open the editor directly for replies.
      set askcc
      set fcc_attach
      set forward_format = "Fwd: %s"
      set forward_decode
      set forward_quote
      set mime_forward
      set attribution = "On %d, %n wrote:"
      set reply_to
      set reverse_name # Use the message's recipient address for replies.
      set include
      set text_flowed=yes
      unset sig_dashes
      unset markers

      # Sort conversations by the last message date, from last to first.
      set charset = "utf-8"
      set uncollapse_jump
      set sort_re
      set sort = reverse-threads
      set sort_aux = last-date-received
      set reply_regexp = "^(([Rr][Ee]?(\[[0-9]+\])?: *)?(\[[^]]+\] *)?)*"
      set quote_regexp = "^( {0,4}[>|:#%]| {0,4}[a-z0-9]+[>|]+)+"
      set send_charset = "utf-8:iso-8859-1:us-ascii"

      set sidebar_short_path
      set sidebar_folder_indent
      set sidebar_format = "%B %* [%?N?%N / ?%S]"
      set mail_check_stats
      bind index,pager \CJ sidebar-prev
      bind index,pager \CK sidebar-next
      bind index,pager \CE sidebar-open

      set mail_check_stats
      set sleep_time = 0

      set help = no
      set status_on_top = yes
      set status_format = "  %u %?p?  %p&?%?F?   %F&? %>  %m "

      set index_format  = "%4C %?X?& ?%S %.70s %> %L %D"
      set flag_chars    = "d  "


      bind index r imap-fetch-mail
      bind pager,browser   h			exit
      bind attach,alias			h			exit
      bind pager				l			view-attachments
      bind pager 				k 			previous-line
      bind pager 				j 			next-line
      bind pager				g			top
      bind pager				G			bottom
      bind index				 j			next-entry
      bind index				 k			previous-entry
      bind attach,index  g 			first-entry
      bind attach,index  G 			last-entry
      bind index         l			display-message
      bind attach	       l			view-attach
      bind browser,alias l			select-entry
      bind index				/			search
      bind index,pager 			R			group-reply
      # The hjkl bindings replace l, ? and h.
      # Use other keys for limit, help and display-toggle-weed.
      bind index				?			limit
      bind index,pager,attach			<F1>			help
      bind pager				H			display-toggle-weed
      bind attach,index,pager 		\CD 			next-page
      bind attach,index,pager 		\CU 			previous-page
      bind index,pager B sidebar-toggle-visible

      set mailcap_path   = ${mailcap}
      auto_view text/html

      color index yellow default '.*'
      color index_author green default '.*'
      color index_number blue default
      color index_subject white default '.*'

      # ~N = new mail
      color index brightyellow black "~N"
      color index_author brightgreen black "~N"
      color index_subject brightwhite black "~N"

      color header blue default ".*"
      color header brightmagenta default "^(From)"
      color header brightwhite default "^(Subject)"
      color header brightcyan default "^(CC|BCC)"

      mono bold bold
      mono underline underline
      mono indicator reverse
      mono error bold
      color normal default default
      color indicator brightblack white
      color sidebar_highlight red default
      color sidebar_divider brightblack black
      color sidebar_flagged red black
      color sidebar_new green black
      color normal brightyellow default
      color error red default
      color tilde black default
      color message cyan default
      color markers red white
      color attachment white default
      color search brightmagenta default
      color status brightyellow black
      color hdrdefault brightgreen default
      color quoted green default
      color quoted1 blue default
      color quoted2 cyan default
      color quoted3 yellow default
      color quoted4 red default
      color quoted5 brightred default
      color signature brightgreen default
      color bold black default
      color underline black default
      color normal default default

      color body brightcyan default "[\-\.+_a-zA-Z0-9]+@[\-\.a-zA-Z0-9]+" # Email addresses
      color body brightblue default "(https?|ftp)://[\-\.,/%~_:?&=\#a-zA-Z0-9]+" # URL
      color body green default "\`[^\`]*\`" # Inline code
      color body brightblue default "^# \.*"
      color body brightcyan default "^## \.*"
      color body brightgreen default "^### \.*"
      color body yellow default "^(\t| )*(-|\\*) \.*" # List items
      color body brightcyan default "[;:][-o][)/(|]" # emoticons
      color body brightcyan default "[;:][)(|]" # emoticons
      color body brightcyan default "[ ][*][^*]*[*][ ]?" # Emphasis between asterisks
      color body brightcyan default "[ ]?[*][^*]*[*][ ]" # Emphasis between asterisks
      color body red default "(BAD signature)"
      color body cyan default "(Good signature)"
      color body brightblack default "^gpg: Good signature .*"
      color body brightyellow default "^gpg: "
      color body brightyellow red "^gpg: BAD signature from.*"
      mono body bold "^gpg: Good signature"
      mono body bold "^gpg: BAD signature from.*"
      color body red default "([a-z][a-z0-9+-]*://(((([a-z0-9_.!~*'();:&=+$,-]|%[0-9a-f][0-9a-f])*@)?((([a-z0-9]([a-z0-9-]*[a-z0-9])?)\\.)*([a-z]([a-z0-9-]*[a-z0-9])?)\\.?|[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+)(:[0-9]+)?)|([a-z0-9_.!~*'()$,;:@&=+-]|%[0-9a-f][0-9a-f])+)(/([a-z0-9_.!~*'():@&=+$,-]|%[0-9a-f][0-9a-f])*(;([a-z0-9_.!~*'():@&=+$,-]|%[0-9a-f][0-9a-f])*)*(/([a-z0-9_.!~*'():@&=+$,-]|%[0-9a-f][0-9a-f])*(;([a-z0-9_.!~*'():@&=+$,-]|%[0-9a-f][0-9a-f])*)*)*)?(\\?([a-z0-9_.!~*'();/?:@&=+$,-]|%[0-9a-f][0-9a-f])*)?(#([a-z0-9_.!~*'();/?:@&=+$,-]|%[0-9a-f][0-9a-f])*)?|(www|ftp)\\.(([a-z0-9]([a-z0-9-]*[a-z0-9])?)\\.)*([a-z]([a-z0-9-]*[a-z0-9])?)\\.?(:[0-9]+)?(/([-a-z0-9_.!~*'():@&=+$,]|%[0-9a-f][0-9a-f])*(;([-a-z0-9_.!~*'():@&=+$,]|%[0-9a-f][0-9a-f])*)*(/([-a-z0-9_.!~*'():@&=+$,]|%[0-9a-f][0-9a-f])*(;([-a-z0-9_.!~*'():@&=+$,]|%[0-9a-f][0-9a-f])*)*)*)?(\\?([-a-z0-9_.!~*'();/?:@&=+$,]|%[0-9a-f][0-9a-f])*)?(#([-a-z0-9_.!~*'();/?:@&=+$,]|%[0-9a-f][0-9a-f])*)?)[^].,:;!)? \t\r\n<>\"]"

      set crypt_use_gpgme=yes
      set crypt_autosign=yes
      set crypt_verify_sig=yes
      set crypt_replysign=yes
      set crypt_replyencrypt=yes
      set crypt_replysignencrypted=yes
      set crypt_autoencrypt = yes


      set pgp_default_key="4F41D2DFD42D5568"
      set pgp_check_gpg_decrypt_status_fd
      set pgp_use_gpg_agent = yes
      set pgp_self_encrypt = yes
    '';
  }
