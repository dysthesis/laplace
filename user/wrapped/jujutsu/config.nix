{
  pkgs,
  lib,
  ...
}: let
  inherit (lib) getExe;
in
  with pkgs; rec {
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
    revset-aliases = {
      "HEAD" = ''coalesce(@ ~ description(exact:""), @-)'';
      "desc(x)" = "description(x)";
      "user()" = ''user("${user.email}")'';
      "user(x)" = "author(x) | committer(x)";
      "closest_bookmark(to)" = "heads(::to & bookmarks())";
      "closest_pushable(to)" = ''heads(::to & mutable() & ~description(exact:"") & (~empty() | merges()))'';
      "pending()" = ".. ~ ::tags() ~ ::remote_bookmarks() ~ @ ~ private()";
      "private()" = ''
        description(glob:'wip:*') | description(glob:'private:*') |
        description(glob:'WIP:*') | description(glob:'PRIVATE:*') |
            conflicts() | (empty() ~ merges()) | description('substring-i:"DO NOT MAIL"')
      '';
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
