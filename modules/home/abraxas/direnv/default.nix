{
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    fold
    toLower
    ;
in {
  programs.direnv =
    {
      enable = true;
    }
    # Automatically enable integration with any enabled shells
    // fold
    (curr: acc:
      acc
      // {"enable${curr}Integration" = config.programs.${toLower curr}.enable;})
    {}
    ["Zsh" "Bash" "Fish"];
}
