{lib, ...}: let
  inherit (lib.laplace.options) mkEnumOption;
  inherit (lib.laplace.modules) importInDirectory;
in {
  options.laplace.security.privesc = mkEnumOption {
    elems = [
      "doas"
      "sudo"
    ];
    description = "Which privilege escalation program to use.";
  };

  imports = importInDirectory ./.;
}
