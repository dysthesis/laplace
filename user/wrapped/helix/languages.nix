{pkgs, ...}: let
  tomlFormat = pkgs.formats.toml {};
  config = {
    language = [
      {
        name = "nix";
        formatter = {
          command = "alejandra";
        };
        language-servers = [
          "nixd"
          "nil"
        ];
        auto-format = true;
      }
    ];
    language-server = {};
  };
in
  tomlFormat.generate "languages.toml" config
