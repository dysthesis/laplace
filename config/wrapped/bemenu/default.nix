{
  pkgs,
  lib,
  ...
}:
let
  bemenu = pkgs.bemenu.overrideAttrs (old: {
    patches = [
      # NOTE: This pull request enables fuzzy finding via the '-z' flag
      (pkgs.fetchpatch {
        url = "https://patch-diff.githubusercontent.com/raw/Cloudef/bemenu/pull/432.patch";
        hash = "sha256-x9y16hmqjzHhs0RzKUTytP+NgAfXNcBVDmMOSWcXL1s=";
      })
    ];
  });
  inherit (lib.babel.pkgs) mkWrapper;
  inherit (builtins) concatStringsSep;
  flags = [
    "-b" # bottom
    ''-z'' # fuzzy
    ''-i'' # ignorecase
    ''-p \" \"'' # prompt
    ''--fn \"JBMono Nerd Font 9\"''
    ''-H \"26\"''
    ''--hp \"8\"''
    ''--fb \"#000000\"''
    ''--ff \"#ffffff\"''
    ''--nb \"#000000\"''
    ''--nf \"#ffffff\"''
    ''--tb \"#7788AA\"''
    ''--hb \"#080808\"''
    ''--tf \"#000000\"''
    ''--hf \"#7788AA\"''
    ''--ab \"#000000\"''
  ];
  flags' = flags |> map (flag: ''--add-flags "${flag}"'') |> concatStringsSep " ";
in
mkWrapper pkgs bemenu
  # sh
  ''
    for file in $out/bin/*; do
      wrapProgram $file ${flags'}
    done
  ''
