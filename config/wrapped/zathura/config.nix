lib:
let
  inherit (lib) isBool concatStringsSep mapAttrsToList;

  options = {
    recolor = true;
    adjust-open = "best-fit";
    pages-per-row = 1;
    scroll-page-aware = true;
    smooth-scroll = true;
    selection-clipboard = "clipboard";
    guioptions = "";
    zoom-min = 10;
    render-loading = false;
    scroll-full-overlap = "0.01";
    scroll-step = 100;
    default-bg = "rgba(0,0,0,0.5)";
    default-fg = "#ffffff";
    recolor-darkcolor = "#ffffff";
    recolor-lightcolor = "rgba(0,0,0,0.5)";
  };

  formatLine =
    n: v:
    let
      formatValue = v: if isBool v then (if v then "true" else "false") else toString v;
    in
    ''set ${n}	"${formatValue v}"'';
in
concatStringsSep "\n" (mapAttrsToList formatLine options) + "\n"
