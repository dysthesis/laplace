{
  pkgs,
  lib,
  ...
}:
pkgs.writeTextFile {
  name = "neomutt-mailcap";
  text = ''
    text/html; ${lib.getExe pkgs.w3m} -I %{charset} -T text/html; copiousoutput;
    application/pdf; ${lib.getExe pkgs.configured.zathura} %s;
  '';
}
