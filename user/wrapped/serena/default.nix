{
  pkgs,
  serena,
  ...
}:
pkgs.symlinkJoin {
  name = "serena-wrapped";
  paths = [serena];
  buildInputs = [pkgs.makeWrapper];
  postBuild = ''
    wrapProgram $out/bin/serena --unset PYTHONPATH
    wrapProgram $out/bin/serena-hooks --unset PYTHONPATH
  '';
}
