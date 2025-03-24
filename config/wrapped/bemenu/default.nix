{
  pkgs,
  lib,
  ...
}:
let
  bemenu = pkgs.bemenu.overrideAttrs (old: {
    patches = [
      (pkgs.fetchpatch {
        url = "https://patch-diff.githubusercontent.com/raw/Cloudef/bemenu/pull/432.patch";
        hash = "sha256-x9y16hmqjzHhs0RzKUTytP+NgAfXNcBVDmMOSWcXL1s=";
      })
    ];
  });
  inherit (lib.babel.pkgs) mkWrapper;
  inherit (builtins) concatStringsSep;
  flags = [
    "-b"
    ''-z''
    ''-p \" \"''
    ''--fn \"JBMono Nerd Font 10\"''
    ''-H \"32\"''
    ''--hp \"8\"''
    ''--fb \"#000000\"''
    ''--ff \"#ffffff\"''
    ''--nb \"#000000\"''
    ''--nf \"#ffffff\"''
    ''--tb \"#89b4fa\"''
    ''--hb \"#11111b\"''
    ''--tf \"#000000\"''
    ''--hf \"#89b4fa\"''
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
