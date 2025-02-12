{lib, ...}: let
  inherit (lib.babel.modules) importInDirectory;
  inherit (lib.babel.path) getDirectories;
  inherit (lib) mkOption;
  inherit (lib.types) enum;
in {
  options.laplace.security.privesc = mkOption {
    type = enum (getDirectories ./.);
    description = "Which privilege escalation program to use.";
    default = "sudo";
  };

  imports = importInDirectory ./.;
}
