{
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    toLower
    fold
    ;
in {
  programs.zoxide =
    {
      enable = true;
      options = [
        "--cmd cd"
      ];
    } # Automatically enable integration with any enabled shells
    // fold
    (curr: acc:
      acc
      // {"enable${curr}Integration" = config.programs.${toLower curr}.enable;})
    {}
    ["Zsh" "Bash" "Fish"];
}
