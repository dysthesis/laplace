{
  lib,
  pkgs,
  irssi,
  writeTextFile,
  writeShellScriptBin,
  config,
  proxychains-ng,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;

  irssiConfig = writeTextFile {
    name = "config";
    text = ''
      servers = (
        {
          address = "palladium.libera.chat";
          chatnet = "libera";
          port = "6697";
          use_tls = "yes";
          tls_verify = "yes";
          tls_cert = "${config.sops.secrets.libera.path}";
        },
      );

      chatnets = {
        libera = {
          type      = "IRC";
          max_kicks = "1";
          max_msgs  = "4";
          max_whois = "1";
          sasl_username = "dysthesis";
          sasl_mechanism = "EXTERNAL";
          sasl_password = "";
        };
      };

      channels = (
        { name = "#irssi";     chatnet = "liberachat";  autojoin = "Yes"; },
      );

      aliases = {
        J           = "JOIN";
        M           = "MSG";
        N           = "NAMES";
        NMSG        = "^MSG";
        NS          = "QUOTE NS";
        OS          = "QUOTE OS";
        Q           = "QUERY";
        RUN         = "SCRIPT LOAD";
        SAY         = "MSG *";
        SB          = "SCROLLBACK";
        SBAR        = "STATUSBAR";
        SHELP       = "QUOTE HELP";
        SIGNOFF     = "QUIT";
        SV          = "MSG * Irssi $J ($V) - https://irssi.org";
        T           = "TOPIC";
        UMODE       = "MODE $N";
        W           = "WHO";
        WC          = "WINDOW CLOSE";
        WG          = "WINDOW GOTO";
        WJOIN       = "JOIN -window";
        WI          = "WHOIS";
        WII         = "WHOIS $0 $0";
        WL          = "WINDOW LIST";
        WN          = "WINDOW NEW HIDDEN";
        WQUERY      = "QUERY -window";
        WW          = "WHOWAS";
      };

      statusbar = {
        items = {

          barstart = "{sbstart}";
          barend   = "{sbend}";

          topicbarstart = "{topicsbstart}";
          topicbarend   = "{topicsbend}";

          time = "{sb $Z}";
          user = "{sb {sbnickmode $cumode}$N{sbmode $usermode}{sbaway $A}}";

          window       = "{sb $winref:$tag/$itemname{sbmode $M}}";
          window_empty = "{sb $winref{sbservertag $tag}}";

          prompt       = "{prompt $[.15]itemname}";
          prompt_empty = "{prompt $winname}";

          topic       = " $topic";
          topic_empty = " Irssi v$J - https://irssi.org";

          lag  = "{sb Lag: $0-}";
          act  = "{sb Act: $0-}";
          more = "-- more --";
        };

        default = {
          window = {

            disabled  = "no";
            type      = "window";
            placement = "bottom";
            position  = "1";
            visible   = "active";

            items = {
              barstart     = { priority = "100"; };
              time         = { };
              user         = { };
              window       = { };
              window_empty = { };
              lag          = { priority = "-1"; };
              act          = { priority = "10"; };
              more         = { priority = "-1";  alignment = "right"; };
              barend       = { priority = "100"; alignment = "right"; };
            };
          };

          window_inact = {

            type      = "window";
            placement = "bottom";
            position  = "1";
            visible   = "inactive";

            items = {
              barstart     = { priority = "100"; };
              window       = { };
              window_empty = { };
              more         = { priority = "-1";  alignment = "right"; };
              barend       = { priority = "100"; alignment = "right"; };
            };
          };

          prompt = {
            type      = "root";
            placement = "bottom";
            position  = "100";
            visible   = "always";

            items = {
              prompt       = { priority = "-1"; };
              prompt_empty = { priority = "-1"; };
              input        = { priority = "10"; };
            };
          };

          topic = {

            type      = "root";
            placement = "top";
            position  = "1";
            visible   = "always";

            items = {
              topicbarstart = { priority = "100"; };
              topic         = { };
              topic_empty   = { };
              topicbarend   = { priority = "100"; alignment = "right"; };
            };
          };
        };
      };
      settings = {
        core = {
          real_name = "Dysthesis";
          user_name = "dysthesis";
          nick = "dysthesis";
        };
      };
    '';
  };
  wrappedIrssi =
    mkWrapper pkgs irssi
    /*
    sh
    */
    ''
      wrapProgram $out/bin/irssi \
        --add-flags "--config=${irssiConfig}"
    '';
in
  writeShellScriptBin "irssi" ''
    ${config.programs.proxychains.package}/bin/proxychains4 ${wrappedIrssi}/bin/irssi
  ''
