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
    template-aliases."format_timestamp(timestamp)" = "timestamp.ago()";
    git.sign-on-push = true;
    signing = {
      behaviour = "own";
      backend = "gpg";
      key = "6008B52F296392B0";
    };
    merge-tools.diffconflicts = {
      program = "nvim";
      merge-args = [
        "-c"
        "let g:jj_diffconflicts_marker_length=$marker_length"
        "-c"
        "JJDiffConflicts!"
        "$output"
        "$base"
        "$left"
        "$right"
      ];
    };
    merge-tool-edits-conflict-markers = true;
    revset-aliases = {
      "closest_bookmark(to)" = "heads(::to & bookmarks())";
      "closest_pushable(to)" = ''heads(::to & mutable() & ~description(exact:"") & (~empty() | merges()))'';
    };
    aliases = {
      tug = [
        "bookmark"
        "move"
        "--from"
        "closest_bookmark($change_id)"
        "--to"
        "closest_pushable($change_id)"
      ];
      patch = [
        "push"
        "rad"
        "HEAD:refs/patches"
      ];
    };
    ui = {
      diff-formatter = [
        "${getExe difftastic}"
        "--color=always"
        "$left"
        "$right"
      ];
    };
  }
