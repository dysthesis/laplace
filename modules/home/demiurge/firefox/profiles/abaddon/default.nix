{
  inputs,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.strings) concatLines;
  inherit
    (builtins)
    readFile
    readDir
    attrNames
    ;
  inherit
    (lib)
    hasSuffix
    filter
    ;
  inherit (lib.laplace.modules) importNixInDirectory;
  filesOfType = extension: path:
    filter
    (name: hasSuffix extension name)
    (attrNames (readDir path));
in {
  programs.firefox.profiles.abaddon = {
    name = "Abaddon";

    userChrome =
      concatLines
      (map
        (file: readFile ./chrome/${file})
        (filesOfType ".css" ./chrome));
  };

  imports = importNixInDirectory "default.nix" ./.;
  home.packages = with pkgs;
  with inputs.babel.packages.${pkgs.system}; [
    georgia-fonts
    sf-pro
    jbcustom-nf
    # nerd-fonts.jetbrains-mono
  ];
}
