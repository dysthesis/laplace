# DiscordIntegration-Fabric config as Nix data, rendered to
# config/Discord-Integration.toml via pkgs.formats.toml. botToken/botChannel are
# @VAR@ placeholders substituted at server start from the sops env file by
# nix-minecraft, so neither enters the store. Field docs ported from the mod
# default; canonical reference https://wiki.erdbeerbaerlp.de/dcintegration.
{
  # General options for the bot
  general = {
    # Bot token. Substituted at server start from the sops env file
    # (DISCORD_BOT_TOKEN); never resolved at build, never in the store.
    botToken = "@DISCORD_BOT_TOKEN@";
    # The channel ID the bot works in. Substituted at start from the sops env
    # file (DISCORD_CHANNEL_ID).
    botChannel = "@DISCORD_CHANNEL_ID@";
    # The bots status message
    # PLACEHOLDERS: %online% - Online Players, %max% - Maximum Player Amount
    botStatusName = "%online% players online";
    # The bots status message for 1 online player, set to empty to use botStatusName
    botStatusNameSingular = "%online% player online";
    # The bots status message for no online players, set to empty to use botStatusName
    botStatusNameEmpty = "No one is online, lock in Anika.";
    # Type of the bots status
    # Allowed Values: DISABLED,PLAYING,WATCHING,LISTENING,STREAMING,COMPETING,CUSTOM
    botStatusType = "PLAYING";
    # URL of the bots stream when using the status type 'STREAMING'
    # Has to start with https://twitch.tv/ or https://www.youtube.com/watch?v=
    streamingURL = "https://www.youtube.com/watch?v=dQw4w9WgXcQ";
    # Enable checking for updates? Notification shown after every server start in
    # log when an update is available.
    enableUpdateChecker = false;
    # The minimum release type for the update checker to notify
    # Allowed values: release, beta, alpha
    updateCheckerMinimumReleaseType = "beta";
    # Set to false to disable config migration from other mods/plugins to this one.
    # This does not prevent updating of this config after mod updates.
    allowConfigMigration = true;
    # Set to true to suppress warning of unsafe mod download location
    ignoreFileSource = false;
    # Set to true to allow relaying webhook messages
    allowWebhookMessages = false;
    # Set to false to disable automatic config tweaking to fix known issues. Your
    # config file will not be sent anywhere during this. (Not implemented yet.)
    allowAutomaticBugFixing = true;
  };

  # Some settings that can be tweaked to increase compatibility with other mods
  compatibility = {
    # Disables modifying sent chat messages in-game to show who was pinged (will
    # not convert <@1234567890> to @User). May fix mods also modifying messages.
    disableParsingMentionsIngame = false;
  };

  # Configuration options for commands
  commands = {
    # Toggle the entire command feature. Disabling this disables registering any
    # commands to discord.
    enabled = true;
    # The Role IDs of your Admin Roles (multiple roles which can access admin commands)
    adminRoleIDs = ["1525803665233805513"];
    # Enable the list command in discord
    listCmdEnabled = true;
    # Show list command only for the user who runs it
    hideListCmd = true;
    # Enable the uptime command in discord
    uptimeCmdEnabled = true;
    # Show uptime command only for the user who runs it
    hideUptimeCmd = false;
    # Enables using local commands for faster registration. Local Commands register
    # all slash commands directly to the server instead of to the bot. Setting this
    # to true requires the bot invited with the scope 'application.commands'.
    useLocalCommands = false;
    # Custom commands. Generate some at https://erdbeerbaerlp.de/dcintegration-commands/
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

  # Toggle some message related features
  messages = {
    # Language key (like en-US, de-DE) downloads the latest language file from
    # github.com/ErdbeerbaerLP/Discord-Integration-Translations. 'local' disables it.
    language = "local";
    # Should /say output be sent to discord?
    sendOnSayCommand = true;
    # Should /me output be sent to discord?
    sendOnMeCommand = true;
    # A selector (ex. @a) relays all /tellraw messages sent with that exact same
    # selector to discord. Leave blank to disable.
    tellrawSelector = "";
    # When a /say command's message starts with this prefix it is not sent to
    # discord. Useful for hiding system messages by prepending it with this.
    sayCommandIgnoredPrefix = "§4§6§k§r";
    # Should Discord users have their role color in-game?
    discordRoleColorIngame = true;
    # Should you be able to hover and click on the discord username in-game?
    enableHoverMessage = true;
    # Characters removed from usernames and chat messages before sending TO discord
    charBlacklist = ["࿕" "࿖"];
  };

  # Settings for embed mode. Each sub-block below shares the same fields:
  #   asEmbed      - send as embed?
  #   colorHexCode - color of the embed bar
  #   customJSON   - custom embed JSON, overrides colorHexCode. Placeholders:
  #                  wiki.erdbeerbaerlp.de/dcintegration:custom-embeds
  embedMode = {
    # Enabling this sends configured messages as embeds (see sub-blocks below)
    enabled = true;
    # Starting & Started Messages
    startMessages = {
      asEmbed = true;
      colorHexCode = "#57f287";
      customJSON = "";
    };
    # Stop & Crash Messages
    stopMessages = {
      asEmbed = true;
      colorHexCode = "#ed4245";
      customJSON = "";
    };
    # Player join message. customJSON adds player head as author icon; color
    # is decimal RGB (Discord embed JSON).
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
    # Player leave messages (also containing timeouts)
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
    # Player Death message. Dark red; black bar invisible on dark theme.
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
    # Advancement messages
    advancementMessage = {
      asEmbed = true;
      colorHexCode = "#fee75c";
      customJSON = "";
    };
    # Player chat messages: plain text. Webhook already shows name + avatar;
    # an embed box per chat line is clutter.
    chatMessages = {
      # Generate unique chat colors from player uuid?
      generateUniqueColors = true;
      asEmbed = false;
      colorHexCode = "#808080";
      customJSON = "";
    };
  };

  # Advanced options. Channel overrides default to 'default' = the main channel.
  advanced = {
    # Custom channel ID for server specific messages (like Join/leave)
    serverChannelID = "default";
    # Custom channel ID for death messages
    deathsChannelID = "default";
    # Custom channel for in-game messages
    chatOutputChannelID = "default";
    # Custom channel where messages get sent to minecraft
    chatInputChannelID = "default";
    # Target URL for the API, for custom discord instances like Spacebar.
    # DO NOT CHANGE if you don't know what you are doing!!
    baseAPIUrl = "https://discord.com";
  };

  # Config options which usually only have an effect when using forge. sendItemInfo
  # was ported to fabric but kept here for config compatibility.
  forgeSpecific = {
    # Blacklisted modids; prevents the mod sending messages to discord via forge's
    # IMC system.
    IMC_modIdBlacklist = ["examplemod"];
    # Show item information (visible on hover in-game) as an embed in discord?
    sendItemInfo = true;
  };

  # Configuration for linking
  linking = {
    # Unlink players when they leave the discord server (leave/kick/ban)?
    unlinkOnLeave = true;
    # Should discord linking be enabled? If whitelist is on, this can NOT be
    # disabled. DOES NOT WORK IN OFFLINE MODE!
    enableLinking = true;
    # Set Discord nicknames to match Minecraft usernames when linked
    shouldNickname = false;
    # Enable global linking? Does not work in offline mode.
    globalLinking = true;
    # Database interface class. Change your database implementation via the addon
    # system. Do not change without knowing what you are doing.
    databaseClass = "de.erdbeerbaerlp.dcintegration.common.storage.linking.database.JSONInterface";
    # Role ID a player gets when they link their discord account. 0 disables.
    linkedRoleID = "0";
    # Enable discord based whitelist? Overrides the link config! Whitelist via the
    # whitelist command in the bot DMs. Does NOT override the vanilla whitelist.
    whitelistMode = false;
    # Role IDs here require the player to have at least ONE to link their account
    requiredRoles = [];
    # Setting keys here are prevented from being changed (still shown in the list)
    settingsBlacklist = [];
    # Default values of some personal settings
    personalSettingsDefaults = {
      default_useDiscordNameInChannel = true;
      default_ignoreReactions = false;
      default_pingSound = true;
    };
  };

  # Webhook configuration
  webhook = {
    # Bot creates a webhook (standard channels only); chat then shows as the
    # player (name + skin avatar). Bot needs Manage Webhooks in the channel.
    enable = true;
    # The avatar used for server messages
    serverAvatarURL = "https://raw.githubusercontent.com/ErdbeerbaerLP/Discord-Chat-Integration/master/images/srv.png";
    # The name used for server messages
    serverName = "Retirement Home";
    # Use the server name and avatar for RCON
    useServerNameForRcon = true;
    # Use the server name and avatar for Console
    useServerNameForConsole = true;
    # Where the player avatar is fetched from. PLACEHOLDERS: %uuid%, %uuid_dashless%,
    # %name%, %randomUUID% (defeats discord cache). tydiumcraft supports bedrock
    # (floodgate) and java players.
    playerAvatarURL = "https://api.tydiumcraft.net/v1/players/skin?uuid=%uuid%&type=avatar&randomuuid=%randomUUID%";
    webhookName = "MC_DC_INTEGRATION";
  };

  # Configuration for the in-game command '/discord'
  ingameCommand = {
    # Enable the /discord command to show a custom message with invite URL?
    enabled = true;
    # The message displayed when typing /discord in the server chat
    message = "Join our discord! https://discord.gg/myserver";
    # The message shown when hovering the /discord command message
    hoverMessage = "Click to open the invite url";
    # The url to open when clicking the /discord command text
    inviteURL = "https://discord.gg/myserver";
  };

  # The command log channel logs every command execution
  commandLog = {
    # Channel ID for the command log channel. 0 disables.
    channelID = "0";
    # Log message format. PLACEHOLDERS: %sender%, %cmd% (e.g. "say Hello World"),
    # %cmd-no-args% (e.g. "say").
    message = "%sender% executed command `%cmd%`";
    # Commands that should NOT be logged
    ignoredCommands = ["list" "help" "?"];
    # Invert ignoredCommands (make it ONLY log those commands)
    commandWhitelist = false;
  };

  # Configure votifier integration here (Spigot only)
  votifier = {
    # Should votifier messages be sent to discord?
    enabled = true;
    # Custom channel ID for Votifier messages
    votifierChannelID = "default";
    # Votifier message format. PLACEHOLDERS: %player%, %site%, %addr% ((IP) address).
    message = ":ballot_box: %player% just voted on %site%";
    # Name of the webhook title
    name = "Votifier";
    # URL of the webhook avatar image
    avatarURL = "https://www.cubecraft.net/attachments/bkjvmqn-png.126824/";
  };

  # Configure Dynmap integration here
  dynmap = {
    # Format forwarded to discord. PLACEHOLDERS: %sender%, %msg%.
    dcMessage = "<%sender%> %msg%";
    # Custom channel ID for dynmap chat
    dynmapChannelID = "default";
    # Name of the webhook title
    name = "Dynmap Web-Chat";
    # URL of the webhook avatar image
    avatarURL = "https://static.wikia.nocookie.net/minecraft_gamepedia/images/9/91/Map_Zoom_0.png/revision/latest?cb=20200311153330";
    # Name format forwarded to the dynmap web-chat. PLACEHOLDERS: %name% (incl.
    # nickname), %name#tag% (without nickname).
    webName = "%name% (discord)";
    # Name shown in discord when no name was specified on the website
    unnamed = "Unnamed";
  };

  # Plugin-specific BStats settings. Does not apply to fabric yet (no bstats for it).
  bstats = {
    # Allow sending of installed addon stats (name and version of installed addons)
    sendAddonStats = true;
  };

  # Settings for servers running as a Bungeecord subserver
  bungee = {
    # True if running as a subserver of a bungeecord network needing offline mode.
    # Forces account linking in offline mode. Do NOT use for actual offline-mode
    # servers (breaks linking because of the UUIDs). No floodgate-on-bungee support.
    isBehindBungee = false;
  };
}
