{
  pkgs,
  lib,
  ...
}: let
  inherit (lib) getExe;
in
  with pkgs; {
    user = {
      name = "Dysthesis";
      email = "antheoraviel@protonmail.com";
    };
    signing = {
      behaviour = "own";
      backend = "gpg";
      key = "4F41D2DFD42D5568";
    };
    ui = {
      diff.tool = ["${getExe difftastic}" "--color=always" "$left" "$right"];
    };
  }
