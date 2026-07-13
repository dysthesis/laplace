# DiscordIntegration-Fabric config as Nix data, rendered to
# config/Discord-Integration.toml via pkgs.formats.toml. botToken/botChannel are
# @VAR@ placeholders substituted at server start from the sops env file by
# nix-minecraft, so neither enters the store. Field docs:
# https://wiki.erdbeerbaerlp.de/dcintegration.
{
  general = {
    botToken = "@DISCORD_BOT_TOKEN@";
    botChannel = "@DISCORD_CHANNEL_ID@";
    botStatusName = "%online% players online";
    botStatusNameSingular = "%online% player online";
    botStatusNameEmpty = "No one is online, lock in Anika.";
    botStatusType = "PLAYING";
    streamingURL = "https://www.youtube.com/watch?v=dQw4w9WgXcQ";
    enableUpdateChecker = false;
    updateCheckerMinimumReleaseType = "beta";
    allowConfigMigration = true;
    ignoreFileSource = false;
    allowWebhookMessages = false;
    allowAutomaticBugFixing = true;
  };

  compatibility = {
    disableParsingMentionsIngame = false;
  };

  commands = {
    enabled = true;
    adminRoleIDs = ["1525803665233805513"];
    listCmdEnabled = true;
    hideListCmd = true;
    uptimeCmdEnabled = true;
    hideUptimeCmd = false;
    useLocalCommands = false;
    customCommands = [
      {
        name = "kick";
        description = "Kicks an player from the Server";
        mcCommand = "kick %player% %reason%";
        textToSend = "";
        adminOnly = true;
        hidden = false;
        args = [
          {
            name = "player";
            description = "The player to be kicked";
            optional = false;
          }
          {
            name = "reason";
            description = "Reason for the kick";
            optional = true;
          }
        ];
      }
      {
        name = "stop";
        description = "Stops the server";
        mcCommand = "stop";
        textToSend = "";
        adminOnly = true;
        hidden = false;
        args = [];
      }
      {
        name = "kill";
        description = "Kills an Player or Entity";
        mcCommand = "kill %target%";
        textToSend = "";
        adminOnly = true;
        hidden = false;
        args = [
          {
            name = "target";
            description = "The target(s) for the kill command.";
            optional = false;
          }
        ];
      }
    ];
  };

  messages = {
    language = "local";
    sendOnSayCommand = true;
    sendOnMeCommand = true;
    tellrawSelector = "";
    sayCommandIgnoredPrefix = "§4§6§k§r";
    discordRoleColorIngame = true;
    enableHoverMessage = true;
    charBlacklist = ["࿕" "࿖"];
  };

  embedMode = {
    enabled = true;
    startMessages = {
      asEmbed = true;
      colorHexCode = "#57f287";
      customJSON = "";
    };
    stopMessages = {
      asEmbed = true;
      colorHexCode = "#ed4245";
      customJSON = "";
    };
    playerJoinMessage = {
      asEmbed = true;
      colorHexCode = "#57f287";
      customJSON = builtins.toJSON {
        author = {
          name = "%name% joined the game";
          icon_url = "%avatarURL%";
        };
        color = 5763719; # #57f287
      };
    };
    playerLeaveMessages = {
      asEmbed = true;
      colorHexCode = "#ed4245";
      customJSON = builtins.toJSON {
        author = {
          name = "%name% left the game";
          icon_url = "%avatarURL%";
        };
        color = 15548997; # #ed4245
      };
    };
    # dark red, not the mod's default black: black bars vanish on dark theme
    deathMessage = {
      asEmbed = true;
      colorHexCode = "#992d22";
      customJSON = builtins.toJSON {
        author = {
          name = "%deathMessage%";
          icon_url = "%avatarURL%";
        };
        color = 10038562; # #992d22
      };
    };
    advancementMessage = {
      asEmbed = true;
      colorHexCode = "#fee75c";
      customJSON = "";
    };
    # plain text: webhook already shows name + avatar, embed per chat line is clutter
    chatMessages = {
      generateUniqueColors = true;
      asEmbed = false;
      colorHexCode = "#808080";
      customJSON = "";
    };
  };

  advanced = {
    serverChannelID = "default";
    deathsChannelID = "default";
    chatOutputChannelID = "default";
    chatInputChannelID = "default";
    baseAPIUrl = "https://discord.com";
  };

  # forge-only options, kept for config compatibility (sendItemInfo works on fabric)
  forgeSpecific = {
    IMC_modIdBlacklist = ["examplemod"];
    sendItemInfo = true;
  };

  linking = {
    unlinkOnLeave = true;
    enableLinking = true;
    shouldNickname = false;
    globalLinking = true;
    databaseClass = "de.erdbeerbaerlp.dcintegration.common.storage.linking.database.JSONInterface";
    linkedRoleID = "0";
    whitelistMode = false;
    requiredRoles = [];
    settingsBlacklist = [];
    personalSettingsDefaults = {
      default_useDiscordNameInChannel = true;
      default_ignoreReactions = false;
      default_pingSound = true;
    };
  };

  webhook = {
    enable = true;
    serverAvatarURL = "https://raw.githubusercontent.com/ErdbeerbaerLP/Discord-Chat-Integration/master/images/srv.png";
    serverName = "Retirement Home";
    useServerNameForRcon = true;
    useServerNameForConsole = true;
    # %randomUUID% defeats discord's avatar cache; tydiumcraft resolves both java and bedrock skins
    playerAvatarURL = "https://api.tydiumcraft.net/v1/players/skin?uuid=%uuid%&type=avatar&randomuuid=%randomUUID%";
    webhookName = "MC_DC_INTEGRATION";
  };

  ingameCommand = {
    enabled = true;
    message = "Join our discord! https://discord.gg/myserver";
    hoverMessage = "Click to open the invite url";
    inviteURL = "https://discord.gg/myserver";
  };

  commandLog = {
    channelID = "0";
    message = "%sender% executed command `%cmd%`";
    ignoredCommands = ["list" "help" "?"];
    commandWhitelist = false;
  };

  votifier = {
    enabled = true;
    votifierChannelID = "default";
    message = ":ballot_box: %player% just voted on %site%";
    name = "Votifier";
    avatarURL = "https://www.cubecraft.net/attachments/bkjvmqn-png.126824/";
  };

  dynmap = {
    dcMessage = "<%sender%> %msg%";
    dynmapChannelID = "default";
    name = "Dynmap Web-Chat";
    avatarURL = "https://static.wikia.nocookie.net/minecraft_gamepedia/images/9/91/Map_Zoom_0.png/revision/latest?cb=20200311153330";
    webName = "%name% (discord)";
    unnamed = "Unnamed";
  };

  bstats = {
    sendAddonStats = true;
  };

  bungee = {
    isBehindBungee = false;
  };
}
