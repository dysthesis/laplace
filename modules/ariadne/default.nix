# Originally yoinked from https://github.com/sioodmy/dotfiles/blob/main/modules/homix/default.nix
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    mkOption
    mkEnableOption
    types
    filterAttrs
    attrValues
    mkIf
    mkDerivedConfig
    ;

  inherit (builtins) map listToAttrs attrNames;
in {
  options = {
    ariadne = mkOption {
      default = {};
      type = types.attrsOf (
        types.submodule (
          {
            name,
            config,
            options,
            ...
          }: {
            options = {
              path = mkOption {
                type = types.str;
                description = ''
                  Path to the file relative to the $HOME directory.
                  If not defined, name of attribute set will be used.
                '';
              };
              source = mkOption {
                type = types.path;
                description = "Path of the source file or directory.";
              };
              text = mkOption {
                default = null;
                type = types.nullOr types.lines;
                description = "Text of the file.";
              };
            };
            config = {
              path = lib.mkDefault name;
              source = mkIf (config.text != null) (
                let
                  name' = "ariadne-" + lib.replaceStrings ["/"] ["-"] name;
                in
                  mkDerivedConfig options.text (pkgs.writeText name')
              );
            };
          }
        )
      );
    };
    users.users = mkOption {
      type = types.attrsOf (
        types.submodule {
          options.ariadne = mkEnableOption "Enable ariadne for selected user";
        }
      );
    };
  };

  config = let
    # list of users managed by ariadne
    users = attrNames (filterAttrs (_name: user: user.ariadne) config.users.users);

    ariadne-link = let
      files = map (f: ''
        FILE=$HOME/${f.path}
        mkdir -p $(dirname $FILE)
        ln -sf ${f.source} $FILE
      '') (attrValues config.ariadne);
    in
      pkgs.writeShellScript "ariadne-link" ''
        #!/bin/sh
        ${builtins.concatStringsSep "\n" files}
      '';

    mkService = user: {
      name = "ariadne-${user}";
      value = {
        wantedBy = ["multi-user.target"];
        description = "Setup ariadne environment for ${user}.";
        serviceConfig = {
          Type = "oneshot";
          User = "${user}";
          ExecStart = "${ariadne-link}";
        };
        environment = {
          # epic systemd momento
          HOME = config.users.users.${user}.home;
        };
      };
    };

    services = listToAttrs (map mkService users);
  in {
    systemd.services = services;
  };
}
