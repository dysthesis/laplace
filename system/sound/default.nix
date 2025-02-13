{ lib, ... }:
let
  inherit (lib)
    mkEnableOption
    mkOption
    ;
  inherit (lib.types) enum;

  inherit (lib.babel.modules) importInDirectory;
  inherit (lib.babel.path) getDirectories;
in
{
  options.laplace.sound = {
    enable = mkEnableOption "Enable sound server.";
    server = mkOption {
      type = enum ((getDirectories ./.) ++ [ "none" ]);
      description = "Which sound server to use";
      default = "none";
    };
  };

  imports = importInDirectory ./.;
}
