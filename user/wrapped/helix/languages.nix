{ pkgs, ... }:
let
  tomlFormat = pkgs.formats.toml { };
  config = {
    language = [{
      name = "nix";
      file-types = [ "nix" ];
      auto-format = true;
      formatter = [ "nixfmt" ];
      language-servers = [ "nixd" "nil" ];
    }];
    language-server = { };
  };
in tomlFormat.generate "languages.toml" config
