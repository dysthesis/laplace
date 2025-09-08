{
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) getExe;
in
with pkgs;
{
  user = {
    name = "Dysthesis";
    email = "antheoraviel@protonmail.com";
  };
  template-aliases."format_timestamp(timestamp)" = "timestamp.ago()";
  git.sign-on-push = true;
  signing = {
    behaviour = "own";
    backend = "gpg";
    key = "4F41D2DFD42D5568";
  };
  aliases = {
    tug = [
      "bookmark"
      "move"
      "--from"
      "heads(::@- & bookmarks())"
      "--to"
      "@-"
    ];
    patch = [
      "push"
      "rad"
      "HEAD:refs/patches"
    ];
  };
  ui = {
    diff.tool = [
      "${getExe difftastic}"
      "--color=always"
      "$left"
      "$right"
    ];
  };
}
