{
  pkgs,
  lib,
  ...
}:
let
  inherit (lib.babel.pkgs) mkWrapper;
  inherit (builtins) concatStringsSep;
  flags = [
    "-b"
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
builtins.trace "${flags'}" mkWrapper pkgs pkgs.bemenu
  # sh
  ''
    for file in $out/bin/*; do
      wrapProgram $file ${flags'}
    done
  ''
