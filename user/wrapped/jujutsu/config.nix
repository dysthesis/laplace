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
      key = "4F41D2DFD42D5568";
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
