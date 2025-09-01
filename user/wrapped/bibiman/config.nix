{
  inputs,
  pkgs,
  lib,
  ...
}: {
  general = {
    bibfiles = ["~/Library/Library.bib"];
    editor = "${lib.getExe inputs.poincare.packages.${pkgs.system}.default}";
    pdf_opener = "xdg-open";
    url-opener = "xdg-open";
    note_path = "~/Documents/Notes/Contents/Literature/";
    note_extensions = ["md"];
    file_symbol = " ";
    link_symbol = "󰌹 ";
    note_symbol = "󰧮";
    custom_column = "pubtype";
  };
}
